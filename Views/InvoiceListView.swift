//  InvoiceListView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.3 - Enhanced haptics and micro-animations
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
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
import SwiftData

struct InvoiceListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Invoice.dueDate, order: .forward) private var allInvoices: [Invoice]
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    @State private var filterStatus: InvoiceFilterStatus = .unpaid
    @State private var searchText = ""
    @State private var showingCreateInvoice = false
    @State private var showingAgingReport = false
    @State private var showingPaywall = false
    @State private var showingLimitAlert = false
    @State private var viewAppeared = false
    
    // Haptic Generators
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
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
        }
        .onChange(of: filterStatus) { oldValue, newValue in
            selectionFeedback.selectionChanged()
        }
        .onAppear {
            prepareHaptics()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                viewAppeared = true
            }
        }
    }
    
    // MARK: - Haptic Preparation
    
    private func prepareHaptics() {
        selectionFeedback.prepare()
        impactLight.prepare()
        impactMedium.prepare()
        notificationFeedback.prepare()
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
                            impactLight.impactOccurred()
                            filterStatus = .unpaid
                        }
                        .opacity(viewAppeared ? 1 : 0)
                        .offset(x: viewAppeared ? 0 : -20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: viewAppeared)
                        
                        SummaryCard(
                            title: "Overdue",
                            amount: overdueAmount,
                            color: .red
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            impactLight.impactOccurred()
                            filterStatus = .overdue
                        }
                        .opacity(viewAppeared ? 1 : 0)
                        .offset(x: viewAppeared ? 0 : -20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: viewAppeared)
                        
                        Button {
                            impactMedium.impactOccurred()
                            showingAgingReport = true
                        } label: {
                            HStack {
                                Image(systemName: "chart.bar.fill")
                                Text("Aging Report")
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                            .frame(height: 80)
                            .padding(.horizontal, 16)
                            .background(Color.businessColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .opacity(viewAppeared ? 1 : 0)
                        .offset(x: viewAppeared ? 0 : -20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: viewAppeared)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                
                // Filter tabs
                Picker("Filter", selection: $filterStatus) {
                    ForEach(InvoiceFilterStatus.allCases, id: \.self) { status in
                        Text(status.rawValue).tag(status)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                .opacity(viewAppeared ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.25), value: viewAppeared)
                
                // Invoice list
                if filteredInvoices.isEmpty {
                    ContentUnavailableView {
                        Label("No Invoices", systemImage: "doc.text")
                            .symbolEffect(.bounce, value: viewAppeared)
                    } description: {
                        Text(emptyStateMessage)
                    }
                    .opacity(viewAppeared ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3), value: viewAppeared)
                } else {
                    List {
                        ForEach(Array(filteredInvoices.enumerated()), id: \.element.id) { index, invoice in
                            NavigationLink(value: invoice) {
                                InvoiceRow(invoice: invoice)
                            }
                            .opacity(viewAppeared ? 1 : 0)
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
                        impactMedium.impactOccurred()
                        handleCreateInvoice()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
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
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.businessColor.opacity(0.3), .businessColor.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .symbolEffect(.pulse, value: viewAppeared)
                        .opacity(viewAppeared ? 1 : 0)
                        .scaleEffect(viewAppeared ? 1 : 0.8)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: viewAppeared)
                    
                    VStack(spacing: 12) {
                        Text("Professional Invoicing")
                            .font(.title2.bold())
                        Text("Upgrade to Premium to create professional invoices and get paid faster.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(y: viewAppeared ? 0 : 20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: viewAppeared)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        FeatureCheckmarkRow(icon: "doc.richtext.fill", text: "Professional PDF invoices", delay: 0.15, appeared: viewAppeared)
                        FeatureCheckmarkRow(icon: "clock.fill", text: "Payment tracking & reminders", delay: 0.2, appeared: viewAppeared)
                        FeatureCheckmarkRow(icon: "person.2.fill", text: "Client management", delay: 0.25, appeared: viewAppeared)
                        FeatureCheckmarkRow(icon: "dollarsign.circle.fill", text: "Automatic late fees", delay: 0.3, appeared: viewAppeared)
                    }
                    .padding(.horizontal, 32)
                    
                    VStack(spacing: 16) {
                        TierComparisonRow(tier: "Premium", price: "$12.99/mo", limit: "25 invoices/month", delay: 0.35, appeared: viewAppeared)
                        TierComparisonRow(tier: "Pro", price: "$19.99/mo", limit: "Unlimited invoices", isRecommended: true, delay: 0.4, appeared: viewAppeared)
                    }
                    .padding(.horizontal, 32)
                    
                    Button {
                        impactMedium.impactOccurred()
                        showingPaywall = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                            Text("Upgrade Now")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.primaryTeal)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 32)
                    .opacity(viewAppeared ? 1 : 0)
                    .scaleEffect(viewAppeared ? 1 : 0.9)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.45), value: viewAppeared)
                    
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
        impactMedium.impactOccurred()
        let invoicesToDelete = offsets.map { filteredInvoices[$0] }
        invoicesToDelete.forEach { modelContext.delete($0) }
        
        do {
            try modelContext.save()
            notificationFeedback.notificationOccurred(.success)
        } catch {
            notificationFeedback.notificationOccurred(.error)
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
                .foregroundStyle(.secondary)
            Text(amount.formatted(.currency(code: "USD")))
                .font(.title3.bold())
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
        .accessibilityLabel("\(title) amount: \(amount.formatted(.currency(code: "USD")))")
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
                .scaleEffect(appeared ? 1 : 0)
                .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.1), value: appeared)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(invoice.invoiceNumber)
                        .font(.subheadline.weight(.medium))
                    
                    if invoice.isOverdue {
                        Text("OVERDUE")
                            .font(.caption2.weight(.bold))
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
                        .foregroundStyle(.secondary)
                }
                
                Text(invoice.dueDateStatus)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(invoice.totalAmount.formatted(.currency(code: "USD")))
                    .font(.subheadline.weight(.semibold))
                    .contentTransition(.numericText())
                
                Text(statusText)
                    .font(.caption2)
                    .foregroundStyle(statusColor)
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            appeared = true
        }
    }
    
    private var statusColor: Color {
        switch invoice.status {
        case .draft: return .gray
        case .sent, .viewed: return invoice.isOverdue ? .red : .blue
        case .paid: return .green
        case .partiallyPaid: return .orange
        case .overdue: return .red
        case .cancelled: return .orange
        }
    }
    
    private var statusText: String {
        switch invoice.status {
        case .draft: return "Draft"
        case .sent: return "Sent"
        case .viewed: return "Viewed"
        case .paid: return "Paid"
        case .partiallyPaid: return "Partially Paid"
        case .overdue: return "Overdue"
        case .cancelled: return "Cancelled"
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
            Text(text)
                .font(.subheadline)
            Spacer()
        }
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -10)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(delay), value: appeared)
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
                    if isRecommended {
                        Text("BEST VALUE")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.businessColor)
                            .cornerRadius(4)
                    }
                }
                Text(limit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(price)
                .font(.subheadline.bold())
                .foregroundColor(.primaryTeal)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(delay), value: appeared)
    }
}

#Preview {
    InvoiceListView()
        .modelContainer(for: [Invoice.self, Client.self])
}
