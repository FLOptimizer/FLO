//  InvoiceDashboardCard.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 4.1 - Dynamic Type verification: lineLimit + minimumScaleFactor on all text
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v4.1 - Dynamic Type Verification:
//  ✅ FIXED: "Invoices" header text already had lineLimit + minimumScaleFactor (verified)
//  ✅ FIXED: "Outstanding Balance" label text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Outstanding balance amount text already had lineLimit + minimumScaleFactor (verified)
//  ✅ FIXED: "Avg. time to payment:" label text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Average days value text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "No Invoices Yet" text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Empty state description text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Create Invoice" button text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: AnimatedStatusPill value text already had lineLimit + minimumScaleFactor (verified)
//  ✅ FIXED: AnimatedStatusPill label text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: AnimatedStatusPill amount text missing lineLimit + minimumScaleFactor
//
//  ENHANCEMENTS v3.0:
//  - Animated counter for outstanding balance
//  - Staggered status pill entrance animations
//  - Urgency indicator pulse effect
//  - Empty state icon bounce animation
//  - Create button press animation
//  - Smooth card press feedback
//  - WCAG 2.1 AA Compliant
//
//  CHANGES v3.1 - Accessibility Audit:
//  ✅ Header doc icon hidden from VoiceOver
//  ✅ Chevron navigation icon hidden from VoiceOver
//  ✅ Header text marked with isHeader trait
//  ✅ Card marked with isSummaryElement trait
//  ✅ Empty state decorative icon hidden
//  ✅ Create Invoice button accessibility hint
//  ✅ Outstanding balance label uses spoken currency
//  ✅ Calendar icon in avg payment row hidden
//

import SwiftUI
import SwiftData

// MARK: - Invoice Dashboard Card

struct InvoiceDashboardCard: View {
    @Environment(\.modelContext) private var modelContext
    
    @State private var showingInvoiceList = false
    @State private var isLoading = false
    
    // Animation States
    @State private var cardVisible = false
    @State private var balanceVisible = false
    @State private var pillsVisible = false
    @State private var emptyIconBounce = false
    @State private var urgencyPulse = false
    @State private var createButtonScale: CGFloat = 1.0
    @State private var displayedBalance: Double = 0
    
    private var stats: InvoiceStatistics {
        InvoiceService.shared.getDashboardStats(context: modelContext)
    }
    
    private var urgencyLevel: UrgencyLevel {
        if stats.overdueCount > 3 {
            return .critical
        } else if stats.overdueCount > 0 {
            return .high
        } else if stats.dueThisWeek > 0 {
            return .medium
        } else {
            return .none
        }
    }
    
    private var hasInvoices: Bool {
        stats.totalOutstanding > 0 || stats.overdueCount > 0 || stats.dueThisWeek > 0
    }
    
    var body: some View {
        Button {
            handleTap()
        } label: {
            VStack(spacing: 0) {
                // Header
                HStack {
                    FLOBrandedIcon(icon: .invoices, size: .medium, color: .brandPrimary)
                    
                    Text("Invoices")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .accessibilityAddTraits(.isHeader)
                    
                    Spacer()
                    
                    // Urgency indicator
                    if urgencyLevel != .none && hasInvoices {
                        Image(systemName: urgencyIndicatorIcon)
                            .font(.title3)
                            .foregroundStyle(urgencyColor)
                            .scaleEffect(urgencyPulse ? 1.15 : 1.0)
                            .accessibilityLabel(urgencyAccessibilityLabel)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .padding()
                .opacity(cardVisible ? 1 : 0.001)
                
                Divider()
                
                // Main Content with smooth transition
                Group {
                    if hasInvoices {
                        activeInvoicesContent
                    } else {
                        emptyStateContent
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: hasInvoices)
            }
        }
        .buttonStyle(AnimatedCardButtonStyle())
        .background(Color.floSecondarySystemBackground)
        .cornerRadius(12)
        .floCardShadow(radius: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(cardAccessibilityLabel)
        .accessibilityHint("Double tap to view invoice list")
        .accessibilityAddTraits(.isSummaryElement)
        .onAppear {
            animateEntrance()
        }
        .sheet(isPresented: $showingInvoiceList) {
            NavigationStack {
                InvoiceListView()
                    .navigationTitle("Invoices")
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                HapticService.play(.medium)
                                showingInvoiceList = false
                            }
                        }
                    }
            }
        }
    }
    
    // MARK: - Animations
    
    private func animateEntrance() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            cardVisible = true
        }
        
        withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
            balanceVisible = true
        }
        
        // Animate balance counter
        if hasInvoices {
            animateBalance()
        }
        
        withAnimation(.easeOut(duration: 0.4).delay(0.4)) {
            pillsVisible = true
        }
        
        // Start urgency pulse if needed
        if urgencyLevel != .none && hasInvoices {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true).delay(0.5)) {
                urgencyPulse = true
            }
        }
        
        // Empty state icon bounce
        if !hasInvoices {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(0.5)) {
                emptyIconBounce = true
            }
        }
    }
    
    private func animateBalance() {
        let targetBalance = stats.totalOutstanding
        let duration = 0.8
        let steps = 30
        let stepDuration = duration / Double(steps)
        
        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + (stepDuration * Double(i))) {
                displayedBalance = targetBalance * Double(i) / Double(steps)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.05) {
            displayedBalance = targetBalance
        }
    }
    
    // MARK: - Active Invoices Content
    
    private var activeInvoicesContent: some View {
        VStack(spacing: 16) {
            // Total Outstanding
            VStack(spacing: 4) {
                Text("Outstanding Balance")
                    .font(.subheadline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.secondary)
                
                Text(displayedBalance.formatted(.currency(code: "USD")))
                    .font(.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .fontWeight(.bold)
                    .foregroundStyle(stats.totalOutstanding > 0 ? Color.brandPrimary : .secondary)
                    .contentTransition(.numericText())
                    .accessibilityLabel("Outstanding balance: \(stats.formattedTotalOutstanding)")
            }
            .opacity(balanceVisible ? 1 : 0.001)
            .scaleEffect(balanceVisible ? 1 : 0.95)
            
            // Status Grid
            HStack(spacing: 12) {
                // Overdue
                AnimatedStatusPill(
                    icon: "exclamationmark.triangle.fill",
                    label: "Overdue",
                    value: stats.overdueCount,
                    amount: stats.formattedOverdueAmount,
                    color: stats.overdueCount > 0 ? Color.expenseRed : .gray,
                    isHighlighted: stats.overdueCount > 0,
                    delay: 0,
                    isVisible: pillsVisible
                )
                
                // Due This Week
                AnimatedStatusPill(
                    icon: "clock.fill",
                    label: "Due This Week",
                    value: stats.dueThisWeek,
                    amount: nil,
                    color: stats.dueThisWeek > 0 ? .orange : .gray,
                    isHighlighted: stats.dueThisWeek > 0,
                    delay: 0.1,
                    isVisible: pillsVisible
                )
            }
            
            // Average Days to Payment
            if let avgDays = stats.formattedAverageDays {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text("Avg. time to payment:")
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(avgDays)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.horizontal, 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Average time to payment: \(avgDays)")
                .opacity(pillsVisible ? 1 : 0.001)
                .animation(.easeOut(duration: 0.3).delay(0.3), value: pillsVisible)
            }
        }
        .padding()
        .animation(.easeInOut, value: stats.overdueCount)
    }
    
    // MARK: - Empty State Content
    
    private var emptyStateContent: some View {
        VStack(spacing: 12) {
            InvoicesIllustration()
                .scaleEffect(0.75)
                .frame(height: 105)
            
            Text("No Invoices Yet")
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text("Create your first invoice to start tracking payments")
                .font(.caption)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                createNewInvoice()
            } label: {
                Text("Create Invoice")
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(Color.brandPrimaryText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.brandPrimary.opacity(0.1))
                    .cornerRadius(8)
                    .scaleEffect(createButtonScale)
                    .accessibilityHint("Double tap to create a new invoice")
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .opacity(cardVisible ? 1 : 0.001)
    }
    
    // MARK: - Helper Functions
    
    private func handleTap() {
        HapticService.play(.medium)
        
        showingInvoiceList = true
    }
    
    private func createNewInvoice() {
        HapticService.play(.medium)
        
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            createButtonScale = 0.95
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                createButtonScale = 1.0
            }
        }
        
        print("Create new invoice")
    }
    
    // MARK: - Accessibility Helpers
    
    private var urgencyIndicatorIcon: String {
        switch urgencyLevel {
        case .none:
            return "checkmark.circle.fill"
        case .low:
            return "clock.fill"
        case .medium:
            return "exclamationmark.circle.fill"
        case .high, .critical:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var urgencyColor: Color {
        switch urgencyLevel {
        case .none:
            return .green
        case .low:
            return .blue
        case .medium:
            return .orange
        case .high, .critical:
            return .red
        }
    }
    
    private var urgencyAccessibilityLabel: String {
        switch urgencyLevel {
        case .none:
            return "All invoices current"
        case .low:
            return "Some invoices due soon"
        case .medium:
            return "Attention needed: invoices due this week"
        case .high:
            return "Important: overdue invoices"
        case .critical:
            return "Critical: multiple overdue invoices"
        }
    }
    
    private var cardAccessibilityLabel: String {
        if !hasInvoices {
            return "Invoices: No invoices yet. Create your first invoice."
        }
        
        var label = "Invoices: "
        label += "Outstanding balance \(stats.formattedTotalOutstanding). "
        
        if stats.overdueCount > 0 {
            label += "\(stats.overdueCount) overdue. "
        }
        
        if stats.dueThisWeek > 0 {
            label += "\(stats.dueThisWeek) due this week."
        }
        
        return label
    }
}

// Note: UrgencyLevel enum is defined elsewhere in the project

// MARK: - Animated Status Pill

struct AnimatedStatusPill: View {
    let icon: String
    let label: String
    let value: Int
    let amount: String?
    let color: Color
    let isHighlighted: Bool
    let delay: Double
    let isVisible: Bool
    
    @State private var pillScale: CGFloat = 0.9
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text("\(value)")
                    .font(.title3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(isHighlighted ? color : .secondary)
            
            Text(label)
                .font(.caption2)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            if let amount = amount, isHighlighted {
                Text(amount)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(color)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHighlighted ? color.opacity(0.1) : Color.floTertiarySystemBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHighlighted ? color.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .scaleEffect(pillScale)
        .opacity(isVisible ? 1 : 0.001)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)" + (amount != nil && isHighlighted ? ", \(amount!)" : ""))
        .onChange(of: isVisible) { _, newValue in
            if newValue {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(delay)) {
                    pillScale = 1.0
                }
            }
        }
        .onAppear {
            if isVisible {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(delay)) {
                    pillScale = 1.0
                }
            }
        }
    }
}

// MARK: - Animated Card Button Style

struct AnimatedCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// Note: Color.expenseRed is defined in Color_Extensions.swift

// MARK: - Preview

#Preview("With Invoices") {
    ScrollView {
        VStack(spacing: 20) {
            InvoiceDashboardCard()
                .padding()
                .modelContainer(previewContainerWithData)
        }
    }
    .background(Color.floSystemGroupedBackground)
}

#Preview("Empty State") {
    ScrollView {
        VStack(spacing: 20) {
            InvoiceDashboardCard()
                .padding()
                .modelContainer(previewContainerEmpty)
        }
    }
    .background(Color.floSystemGroupedBackground)
}

// MARK: - Preview Containers

@MainActor
private var previewContainerWithData: ModelContainer = {
    let schema = Schema([
        Invoice.self,
        Client.self,
        InvoiceItem.self
    ])
    
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: configuration)
    
    return container
}()

@MainActor
private var previewContainerEmpty: ModelContainer = {
    let schema = Schema([
        Invoice.self,
        Client.self,
        InvoiceItem.self
    ])
    
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: configuration)
    
    return container
}()

