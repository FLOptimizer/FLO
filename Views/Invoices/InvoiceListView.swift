//  InvoiceListView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.3 - VoiceOver Audit: Decorative icons hidden
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v3.3 - VoiceOver Audit:
//  ✅ ADDED: Status indicator circle in InvoiceRow hidden from VoiceOver (decorative color indicator)
//  ✅ ADDED: Aging Report button icon hidden (text label describes it)
//  ✅ ADDED: Feature checkmark icons hidden (already combined in accessibility label)
//  ✅ ADDED: Upgrade button star icon hidden (text describes action)
//  ✅ ADDED: Locked view document icon hidden (decorative illustration)
//  ✅ IMPROVED: InvoiceRow accessibility label now includes due date status
//  ✅ VERIFIED: InvoiceRow already has combined accessibility label with client, amount, status
//  ✅ VERIFIED: SummaryCards already have accessibility hints for filtering
//
//  CHANGES v3.2 - Dynamic Type Verification:
//  ✅ FIXED: SummaryCard title text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: SummaryCard amount text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Aging Report button text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Filter picker tag text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Empty state "No Invoices" title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Empty state message text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: InvoiceRow invoice number missing lineLimit + minimumScaleFactor
//  ✅ FIXED: InvoiceRow "OVERDUE" badge missing lineLimit + minimumScaleFactor
//  ✅ FIXED: InvoiceRow client name missing lineLimit + minimumScaleFactor
//  ✅ FIXED: InvoiceRow due date status missing lineLimit + minimumScaleFactor
//  ✅ FIXED: InvoiceRow amount text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: InvoiceRow status text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Locked view "Professional Invoicing" title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Locked view description text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: FeatureCheckmarkRow text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: TierComparisonRow tier name missing lineLimit + minimumScaleFactor
//  ✅ FIXED: TierComparisonRow "BEST VALUE" badge missing lineLimit + minimumScaleFactor
//  ✅ FIXED: TierComparisonRow limit text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: TierComparisonRow price text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Upgrade button text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Alert message text missing lineLimit + minimumScaleFactor
//
//  CHANGES v2.4:
//  ✅ Added VoiceOver labels to InvoiceRow (full invoice details)
//  ✅ Added accessibility hints to SummaryCards
//  ✅ Added accessibility to filter picker
//  ✅ Added accessibility to Aging Report button
//  ✅ Added accessibility to locked view elements
//
//  CHANGES v2.3:
//  ✅ Haptic feedback on filter changes
//  ✅ Haptic on summary card taps
//  ✅ Haptic on create/delete actions
//  ✅ List entrance animations
//  ✅ Summary card animations
//  ✅ Empty state icon animation
//  ✅ Invoice row animations
//  ✅ Locked view animations
//
//  PREVIOUS: Added subscription gating wrapper - all original features preserved

import SwiftUI
import FLODesignSystem
import SwiftData

struct InvoiceListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Invoice.dueDate, order: .forward) private var allInvoices: [Invoice]
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    @State private var filterStatus: InvoiceFilterStatus = .all
    @State private var searchText = ""
    @State private var showingCreateInvoice = false
    @State private var showingAgingReport = false
    @State private var showingPaywall = false
    @State private var showingLimitAlert = false
    @State private var viewAppeared = false
    
    var filteredInvoices: [Invoice] {
        var invoices = allInvoices
        
        switch filterStatus {
        case .all:
            break
        case .unpaid:
            invoices = invoices.filter { $0.status != InvoiceStatus.paid && $0.status != InvoiceStatus.cancelled }
        case .overdue:
            invoices = invoices.filter { $0.isOverdue }
        case .paid:
            invoices = invoices.filter { $0.status == InvoiceStatus.paid }
        case .draft:
            invoices = invoices.filter { $0.status == InvoiceStatus.draft }
        }
        
        if !searchText.isEmpty {
            invoices = invoices.filter { invoice in
                invoice.invoiceNumber.localizedCaseInsensitiveContains(searchText) ||
                invoice.client?.name.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }
        
        return invoices
    }
    
    var outstandingAmount: Double {
        allInvoices
            .filter { $0.status != InvoiceStatus.paid && $0.status != InvoiceStatus.cancelled }
            .reduce(0) { $0 + $1.totalAmount }
    }
    
    var overdueAmount: Double {
        allInvoices
            .filter { $0.isOverdue }
            .reduce(0) { $0 + $1.totalAmount }
    }
    
    var body: some View {
        Group {
            if subscriptionManager.currentTier.hasInvoicing {
                invoiceListContent
            } else {
                lockedInvoiceView
            }
        }
        .sheet(isPresented: $showingPaywall) {
            SubscriptionView()
        }
        .alert("Invoice Limit Reached", isPresented: $showingLimitAlert) {
            Button("Upgrade to Pro") {
                showingPaywall = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You've reached the 25 invoice limit for Premium. Upgrade to Pro for unlimited invoices.")
                .lineLimit(3)
                .minimumScaleFactor(0.7)
        }
        .onChange(of: filterStatus) { oldValue, newValue in
            HapticService.play(.selection)
        }
        .onAppear {
            DispatchQueue.main.async {
                withAnimation(FLOAnimation.standard) {
                    viewAppeared = true
                }
            }
        }
    }
    
    // MARK: - Invoice List Content
    
    private var invoiceListContent: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Summary cards with animation
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        SummaryCard(
                            title: "Outstanding",
                            amount: outstandingAmount,
                            color: .blue
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            HapticService.play(.light)
                            filterStatus = .unpaid
                        }
                        .accessibilityHint("Double tap to filter to unpaid invoices")
                        .opacity(viewAppeared ? 1 : 0.001)
                        .offset(x: viewAppeared ? 0 : -20)
                        .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
                        
                        SummaryCard(
                            title: "Overdue",
                            amount: overdueAmount,
                            color: .red
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            HapticService.play(.light)
                            filterStatus = .overdue
                        }
                        .accessibilityHint("Double tap to filter to overdue invoices")
                        .opacity(viewAppeared ? 1 : 0.001)
                        .offset(x: viewAppeared ? 0 : -20)
                        .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)
                        
                        Button {
                            HapticService.play(.medium)
                            showingAgingReport = true
                        } label: {
                            HStack {
                                Image(systemName: "chart.bar.fill")
                                    .accessibilityHidden(true)
                                Text("Aging Report")
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                            .frame(height: 80)
                            .padding(.horizontal, 16)
                            .background(Color.businessColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .accessibilityLabel("Aging Report")
                        .accessibilityHint("Double tap to view invoice aging report")
                        .opacity(viewAppeared ? 1 : 0.001)
                        .offset(x: viewAppeared ? 0 : -20)
                        .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                
                // Filter tabs
                Picker("Filter", selection: $filterStatus) {
                    ForEach(InvoiceFilterStatus.allCases, id: \.self) { status in
                        Text(status.rawValue)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .tag(status)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                .accessibilityLabel("Invoice status filter")
                .accessibilityHint("Select to filter invoices by status")
                .opacity(viewAppeared ? 1 : 0.001)
                .animation(FLOAnimation.standard.delay(0.25), value: viewAppeared)
                
                // Invoice list
                if filteredInvoices.isEmpty {
                    VStack(spacing: 16) {
                        if filterStatus == .all {
                            InvoicesIllustration()
                        }
                        
                        Text("No Invoices")
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        
                        Text(emptyStateMessage)
                            .font(.subheadline)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(32)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("No invoices. \(emptyStateMessage)")
                    .opacity(viewAppeared ? 1 : 0.001)
                    .animation(FLOAnimation.standard.delay(0.3), value: viewAppeared)
                } else {
                    List {
                        ForEach(Array(filteredInvoices.enumerated()), id: \.element.id) { index, invoice in
                            NavigationLink(value: invoice) {
                                InvoiceRow(invoice: invoice)
                            }
                            .opacity(viewAppeared ? 1 : 0.001)
                            .offset(x: viewAppeared ? 0 : 20)
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.8)
                                .delay(0.3 + Double(index) * 0.03),
                                value: viewAppeared
                            )
                        }
                        .onDelete(perform: deleteInvoices)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .searchable(text: $searchText, prompt: "Search invoices or clients")
                }
            }
            .navigationTitle("Invoices")
            .navigationDestination(for: Invoice.self) { invoice in
                InvoiceDetailView(invoice: invoice)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticService.play(.medium)
                        handleCreateInvoice()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .accessibilityLabel("Create new invoice")
                    .accessibilityHint("Double tap to create a new invoice")
                }
            }
            .sheet(isPresented: $showingCreateInvoice) {
                CreateInvoiceView()
            }
            .sheet(isPresented: $showingAgingReport) {
                AgingReportView()
            }
        }
    }
    
    // MARK: - Locked View
    
    private var lockedInvoiceView: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    Spacer().frame(height: 40)
                    
                    Image(systemName: "doc.text.fill")
                        .font(.largeTitle)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.businessColor.opacity(0.3), .businessColor.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .symbolEffect(.pulse, value: viewAppeared)
                        .accessibilityHidden(true)
                        .opacity(viewAppeared ? 1 : 0.001)
                        .scaleEffect(viewAppeared ? 1 : 0.8)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: viewAppeared)
                    
                    VStack(spacing: 12) {
                        Text("Professional Invoicing")
                            .font(.title2.bold())
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .accessibilityAddTraits(.isHeader)
                        Text("Upgrade to Premium to create professional invoices and get paid faster.")
                            .font(.body)
                            .lineLimit(3)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 20)
                    .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        FeatureCheckmarkRow(icon: "doc.richtext.fill", text: "Professional PDF invoices", delay: 0.15, appeared: viewAppeared)
                        FeatureCheckmarkRow(icon: "clock.fill", text: "Payment tracking & reminders", delay: 0.2, appeared: viewAppeared)
                        FeatureCheckmarkRow(icon: "person.2.fill", text: "Client management", delay: 0.25, appeared: viewAppeared)
                        FeatureCheckmarkRow(icon: "dollarsign.circle.fill", text: "Automatic late fees", delay: 0.3, appeared: viewAppeared)
                    }
                    .padding(.horizontal, 32)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Features included: Professional PDF invoices, Payment tracking and reminders, Client management, Automatic late fees")
                    
                    VStack(spacing: 16) {
                        TierComparisonRow(tier: "Premium", price: "$12.99/mo", limit: "25 invoices/month", delay: 0.35, appeared: viewAppeared)
                        TierComparisonRow(tier: "Pro", price: "$19.99/mo", limit: "Unlimited invoices", isRecommended: true, delay: 0.4, appeared: viewAppeared)
                    }
                    .padding(.horizontal, 32)
                    
                    Button {
                        HapticService.play(.medium)
                        showingPaywall = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .accessibilityHidden(true)
                            Text("Upgrade Now")
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.primaryTeal)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 32)
                    .accessibilityLabel("Upgrade Now")
                    .accessibilityHint("Double tap to view subscription options")
                    .opacity(viewAppeared ? 1 : 0.001)
                    .scaleEffect(viewAppeared ? 1 : 0.9)
                    .animation(FLOAnimation.standard.delay(0.45), value: viewAppeared)
                    
                    Spacer()
                }
            }
            .navigationTitle("Invoices")
        }
    }
    
    // MARK: - Helpers
    
    private var emptyStateMessage: String {
        switch filterStatus {
        case .all: return "Create your first invoice to get started"
        case .unpaid: return "No unpaid invoices"
        case .overdue: return "No overdue invoices"
        case .paid: return "No paid invoices"
        case .draft: return "No draft invoices"
        }
    }
    
    private func handleCreateInvoice() {
        guard subscriptionManager.currentTier.hasInvoicing else {
            showingPaywall = true
            return
        }
        
        if subscriptionManager.currentTier == .premium {
            if let limit = subscriptionManager.currentTier.invoiceLimit {
                let thisMonthInvoices = getInvoicesThisMonth()
                if thisMonthInvoices >= limit {
                    showingLimitAlert = true
                    return
                }
            }
        }
        
        showingCreateInvoice = true
    }
    
    private func getInvoicesThisMonth() -> Int {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
        return allInvoices.filter { $0.issueDate >= startOfMonth }.count
    }
    
    private func deleteInvoices(at offsets: IndexSet) {
        HapticService.play(.medium)
        let invoicesToDelete = offsets.map { filteredInvoices[$0] }
        invoicesToDelete.forEach { modelContext.delete($0) }
        
        do {
            try modelContext.save()
            HapticService.play(.success)
        } catch {
            HapticService.play(.error)
        }
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    let title: String
    let amount: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(.secondary)
            Text(amount.formatted(.currency(code: "USD")))
                .font(.title3.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
        }
        .frame(width: 140, height: 80, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(amount.formatted(.currency(code: "USD")))")
    }
}

// MARK: - Invoice Row

struct InvoiceRow: View {
    let invoice: Invoice
    
    @State private var appeared = false
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
                .scaleEffect(appeared ? 1 : 0.001)
                .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.1), value: appeared)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(invoice.invoiceNumber)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    if invoice.isOverdue {
                        Text("OVERDUE")
                            .font(.caption2.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.red)
                            .clipShape(Capsule())
                    }
                }
                
                if let client = invoice.client {
                    Text(client.name)
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                }
                
                Text(invoice.dueDateStatus)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(invoice.totalAmount.formatted(.currency(code: "USD")))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
                
                Text(statusText)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(statusColor)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(invoiceAccessibilityLabel)
        .accessibilityHint("Double tap to view invoice details")
        .onAppear {
            appeared = true
        }
    }
    
    // MARK: - Accessibility
    
    private var invoiceAccessibilityLabel: String {
        var label = "Invoice \(invoice.invoiceNumber)"
        if let client = invoice.client {
            label += " for \(client.name)"
        }
        label += ", \(invoice.totalAmount.formatted(.currency(code: "USD")))"
        label += ", status: \(statusText)"
        if invoice.isOverdue {
            label += ", overdue"
        }
        label += ", \(invoice.dueDateStatus)"
        return label
    }
    
    // MARK: - Computed Properties
    
    private var statusText: String {
        invoice.status.displayName
    }
    
    private var statusColor: Color {
        switch invoice.status {
        case .draft:
            return .gray
        case .sent:
            return .blue
        case .viewed:
            return .orange
        case .paid:
            return .green
        case .partiallyPaid:
                return .orange
        case .overdue:
            return .red
        case .cancelled:
            return .secondary
        }
    }
}
    
// MARK: - Supporting Types

enum InvoiceFilterStatus: String, CaseIterable {
    case all = "All"
    case unpaid = "Unpaid"
    case overdue = "Overdue"
    case paid = "Paid"
    case draft = "Draft"
}

// MARK: - Gating UI Components

struct FeatureCheckmarkRow: View {
    let icon: String
    let text: String
    var delay: Double = 0
    var appeared: Bool = true
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.primaryTeal)
                .frame(width: 32)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
        }
        .opacity(appeared ? 1 : 0.001)
        .offset(x: appeared ? 0 : -10)
        .animation(FLOAnimation.standard.delay(delay), value: appeared)
    }
}

struct TierComparisonRow: View {
    let tier: String
    let price: String
    let limit: String
    var isRecommended: Bool = false
    var delay: Double = 0
    var appeared: Bool = true
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(tier)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if isRecommended {
                        Text("BEST VALUE")
                            .font(.caption2.bold())
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.businessColor)
                            .cornerRadius(4)
                    }
                }
                Text(limit)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(price)
                .font(.subheadline.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundColor(.brandPrimaryText)
        }
        .padding()
        .background(Color.floSecondarySystemGroupedBackground)
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tier) plan, \(price), \(limit)\(isRecommended ? ", Best value" : "")")
        .opacity(appeared ? 1 : 0.001)
        .offset(y: appeared ? 0 : 10)
        .animation(FLOAnimation.standard.delay(delay), value: appeared)
    }
}

#Preview {
    InvoiceListView()
        .modelContainer(for: [Invoice.self, Client.self])
}
