//  RecurringListView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.1.1 - Accessibility: row labels, icon hiding, screen announcement
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES FROM v2.0:
//  ✅ Haptic feedback on row tap, swipe actions
//  ✅ Row entrance stagger animations
//  ✅ Icon scale animation
//  ✅ Add button haptic
//  ✅ Empty state icon animation
//
//  PREVIOUS (v2.0):
//  - Fixed Color(hex:) → Color(flowHex:)

import SwiftUI
import SwiftData

struct RecurringListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \RecurringTransaction.startDate, order: .reverse) private var recurring: [RecurringTransaction]
    
    @State private var showingAddRecurring = false
    @State private var recurringToEdit: RecurringTransaction?
    @State private var viewAppeared = false
    
    // Haptic Generators
                    
    var body: some View {
        NavigationStack {
            List {
                activeSection
                pausedSection
            }
            .navigationTitle("Recurring")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        HapticService.play(.medium)
                        showingAddRecurring = true
                    } label: {
                        Image(systemName: "plus")
                             .foregroundStyle(Color.brandPrimaryText)
                    }
                    .accessibilityLabel("Add recurring transaction")
                    .accessibilityHint("Opens form to create a new recurring bill or income")
                }
            }
            .overlay {
                if recurring.isEmpty {
                    ContentUnavailableView(
                        "No Recurring Transactions",
                        systemImage: "repeat",
                        description: Text("Tap + to add recurring bills or income")
                    )
                    .onAppear {
                        viewAppeared = true
                    }
                }
            }
            .sheet(isPresented: $showingAddRecurring) {
                AddRecurringView()
            }
            .sheet(item: $recurringToEdit) { recur in
                EditRecurringView(recurringTransaction: recur)
            }
            .onAppear {
                withAnimation(FLOAnimation.standard) {
                    viewAppeared = true
                }
                AccessibilityAnnouncement.screenChanged("Recurring transactions")
            }
        }
    }
    
    // MARK: - Haptic Preparation
    
        
    // MARK: - Sections
    
    @ViewBuilder
    private var activeSection: some View {
        if !activeRecurring.isEmpty {
            Section("Active") {
                ForEach(Array(activeRecurring.enumerated()), id: \.element.id) { index, recur in
                    RecurringRow(recurring: recur)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            HapticService.play(.light)
                            recurringToEdit = recur
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                HapticService.play(.heavy)
                                deleteRecurring(recur)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            
                            Button {
                                HapticService.play(.medium)
                                toggleActive(recur)
                            } label: {
                                Label("Pause", systemImage: "pause.fill")
                            }
                            .tint(.orange)
                        }
                        .opacity(viewAppeared ? 1 : 0.001)
                        .offset(x: viewAppeared ? 0 : 20)
                        .animation(
                            FLOAnimation.standard
                            .delay(Double(index) * 0.05),
                            value: viewAppeared
                        )
                }
            }
        }
    }
    
    @ViewBuilder
    private var pausedSection: some View {
        if !pausedRecurring.isEmpty {
            Section("Paused") {
                ForEach(Array(pausedRecurring.enumerated()), id: \.element.id) { index, recur in
                    RecurringRow(recurring: recur)
                        .opacity(0.6)
                        .swipeActions(edge: .leading) {
                            Button {
                                HapticService.play(.medium)
                                toggleActive(recur)
                            } label: {
                                Label("Resume", systemImage: "play.fill")
                            }
                            .tint(.green)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                HapticService.play(.heavy)
                                deleteRecurring(recur)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .opacity(viewAppeared ? 1 : 0.001)
                        .offset(x: viewAppeared ? 0 : 20)
                        .animation(
                            FLOAnimation.standard
                            .delay(0.2 + Double(index) * 0.05),
                            value: viewAppeared
                        )
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var activeRecurring: [RecurringTransaction] {
        recurring.filter { $0.isActive }
    }
    
    private var pausedRecurring: [RecurringTransaction] {
        recurring.filter { !$0.isActive }
    }
    
    // MARK: - Actions
    
    private func toggleActive(_ recurring: RecurringTransaction) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            recurring.isActive.toggle()
            
            do {
                try context.save()
                HapticService.play(.success)
            } catch {
                HapticService.play(.error)
                print("âŒ Failed to toggle recurring: \(error)")
            }
        }
    }
    
    private func deleteRecurring(_ recurring: RecurringTransaction) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            context.delete(recurring)
            
            do {
                try context.save()
                HapticService.play(.success)
            } catch {
                HapticService.play(.error)
                print("âŒ Failed to delete recurring: \(error)")
            }
        }
    }
}

// MARK: - Recurring Row

struct RecurringRow: View {
    let recurring: RecurringTransaction
    @State private var iconAppeared = false
    
    var body: some View {
        HStack(spacing: 12) {
            iconView
            detailsView
            Spacer()
            amountView
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(recurringAccessibilityLabel)
        .accessibilityHint("Double tap to edit. Swipe for more options.")
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                iconAppeared = true
            }
        }
    }
    
    private var recurringAccessibilityLabel: String {
        let type = recurring.isIncome ? "Income" : "Expense"
        let status = recurring.isActive ? "" : ", paused"
        let freq = recurring.frequency.displayName
        let amount = String(format: "$%.2f", recurring.amount)
        return "\(recurring.displayName), \(type), \(amount), \(freq)\(status)"
    }
    
    private var iconView: some View {
        Group {
            if let category = recurring.category {
                Image(systemName: category.icon)
                    .font(.title3)
                    .foregroundStyle(Color(flowHex: category.colorHex))
                    .frame(width: 40, height: 40)
                    .background(Color(flowHex: category.colorHex).opacity(0.1))
                    .cornerRadius(10)
                    .scaleEffect(iconAppeared ? 1 : 0.5)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "repeat")
                    .font(.title3)
                    .foregroundStyle(Color.gray)
                    .frame(width: 40, height: 40)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .scaleEffect(iconAppeared ? 1 : 0.5)
                    .accessibilityHidden(true)
            }
        }
    }
    
    private var detailsView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(recurring.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack(spacing: 4) {
                Text(recurring.frequency.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if let next = recurring.nextOccurrence {
                    Text("• Next: \(next.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Text(recurring.financeType == .business ? "ðŸ¢ Business" : "ðŸ‘¤ Personal")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    private var amountView: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(recurring.amount, format: .currency(code: "USD"))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(recurring.isIncome ? .green : .primary)
                .contentTransition(.numericText())
            
            if !recurring.isActive {
                Text("Paused")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

// MARK: - Preview

#Preview("Recurring List") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: RecurringTransaction.self, Category.self,
        configurations: config
    )
    
    let context = container.mainContext
    
    let subscriptions = Category(
        name: "Subscriptions",
        icon: "tv.fill",
        colorHex: "3B82F6",
        isIncome: false
    )
    context.insert(subscriptions)
    
    let netflix = RecurringTransaction(
        amount: 15.99,
        merchantName: "Netflix",
        note: "Streaming",
        isIncome: false,
        financeType: .personal,
        frequency: .monthly,
        startDate: Date(),
        category: subscriptions,
        isActive: true
    )
    context.insert(netflix)
    
    let rent = RecurringTransaction(
        amount: 1500.00,
        merchantName: "Landlord",
        note: "Rent",
        isIncome: false,
        financeType: .personal,
        frequency: .monthly,
        startDate: Date(),
        isActive: true
    )
    context.insert(rent)
    
    let oldGym = RecurringTransaction(
        amount: 50.00,
        merchantName: "Gym",
        note: "Old membership",
        isIncome: false,
        financeType: .personal,
        frequency: .monthly,
        startDate: Date().addingTimeInterval(-86400 * 180),
        isActive: false
    )
    context.insert(oldGym)
    
    return RecurringListView()
        .modelContainer(container)
}
