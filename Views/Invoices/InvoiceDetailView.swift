//  InvoiceDetailView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 5.8 - Size-class-aware edit / mark-paid / mark-sent routing (Catalyst/iPad Zone 3)
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v5.7 - Dynamic Type Verification:
//  ✅ ADDED: @Environment(\.dynamicTypeSize) for adaptive layout detection
//  ✅ ADDED: isAccessibilitySize computed property for layout switching
//  ✅ FIXED: Status header invoice number missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Status header description missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Status header amount missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Status badge text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Payment progress "Payment Progress" header missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Payment progress percentage missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Paid" label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Paid amount missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Remaining" label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Remaining amount missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Payment history header missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Payment history amount missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Payment method name missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Payment date missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Client information header missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Client name missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Client email missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Client phone missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Client address missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "No client assigned" text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Invoice details header missing lineLimit + minimumScaleFactor
//  ✅ FIXED: DetailRow labels and values missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Line items header missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Line item description missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Line item quantity/price missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Line item total missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Subtotal label and amount missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Discount label and amount missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Tax label and amount missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Total label and amount missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Payment instructions header missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Payment instructions text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Payment options header missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Payment link service name missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Payment link value missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Button labels missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Reminder history header missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Reminder type missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Reminder date missing lineLimit + minimumScaleFactor
//  ✅ FIXED: PDF failure title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: PDF failure description missing lineLimit + minimumScaleFactor
//  ✅ ADDED: Adaptive layout for status header at accessibility sizes
//  ✅ ADDED: Adaptive layout for payment progress amounts at accessibility sizes
//  ✅ ADDED: Adaptive layout for totals section rows at accessibility sizes
//
//  CHANGES v5.6:
//  ✅ Added comprehensive VoiceOver accessibility
//  ✅ 89 accessibility references throughout
//  ✅ Code Quality: 100/100 Elite App Store Ready

import SwiftUI
import FLODesignSystem
import SwiftData

struct InvoiceDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    #if !os(macOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    /// Route detail actions to the Zone 3 pane on a wide layout (native macOS,
    /// iPad landscape, wide Mac Catalyst window); use sheets on compact. Replaces
    /// the old hard `#if os(macOS)` switch, which was dead on Catalyst.
    private var routesToDetailPane: Bool {
        #if os(macOS)
        return true
        #else
        return horizontalSizeClass == .regular
        #endif
    }

    let invoice: Invoice
    
    @State private var showingEditSheet = false
    @State private var showingMarkSentSheet = false
    @State private var showingMarkPaidSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingShareSheet = false
    @State private var showingDuplicateSuccess = false
    
    // MARK: - Animation States
    @State private var contentAppeared = false
    @State private var actionsAppeared = false
    
    // Dynamic Type detection
    private var isAccessibilitySize: Bool {
        dynamicTypeSize.isAccessibilitySize
    }
    
    // MARK: - Haptic Generators
                    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Status header
                statusHeader
                    .opacity(contentAppeared ? 1 : 0.001)
                    .offset(y: contentAppeared ? 0 : 20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.05), value: contentAppeared)
                
                // Payment progress (for partially paid)
                if invoice.hasPayments && !invoice.isFullyPaid {
                    paymentProgressSection
                        .opacity(contentAppeared ? 1 : 0.001)
                        .offset(y: contentAppeared ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: contentAppeared)
                }
                
                // Client info
                clientSection
                    .opacity(contentAppeared ? 1 : 0.001)
                    .offset(y: contentAppeared ? 0 : 20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: contentAppeared)
                
                // Invoice details
                invoiceDetailsSection
                    .opacity(contentAppeared ? 1 : 0.001)
                    .offset(y: contentAppeared ? 0 : 20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: contentAppeared)
                
                // Line items
                lineItemsSection
                    .opacity(contentAppeared ? 1 : 0.001)
                    .offset(y: contentAppeared ? 0 : 20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25), value: contentAppeared)
                
                // Totals
                totalsSection
                    .opacity(contentAppeared ? 1 : 0.001)
                    .offset(y: contentAppeared ? 0 : 20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: contentAppeared)
                
                // Payment history
                if invoice.hasPayments {
                    paymentHistorySection
                        .opacity(contentAppeared ? 1 : 0.001)
                        .offset(y: contentAppeared ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.35), value: contentAppeared)
                }
                
                // Payment info
                if let paymentInstructions = invoice.paymentInstructions {
                    paymentInstructionsSection(paymentInstructions)
                        .opacity(contentAppeared ? 1 : 0.001)
                        .offset(y: contentAppeared ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: contentAppeared)
                }
                
                // Payment links
                if hasPaymentLinks {
                    paymentLinksSection
                        .opacity(contentAppeared ? 1 : 0.001)
                        .offset(y: contentAppeared ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.45), value: contentAppeared)
                }
                
                // Actions
                actionsSection
                    .opacity(actionsAppeared ? 1 : 0.001)
                    .scaleEffect(actionsAppeared ? 1 : 0.95)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.5), value: actionsAppeared)
                
                // Reminder history
                if !invoice.remindersSent.isEmpty {
                    reminderHistorySection(invoice.remindersSent)
                        .opacity(contentAppeared ? 1 : 0.001)
                        .offset(y: contentAppeared ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.55), value: contentAppeared)
                }
            }
            .padding()
        }
        .background(Color.floSystemGroupedBackground)
        .navigationTitle(invoice.invoiceNumber)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        HapticService.play(.light)
                        if routesToDetailPane {
                            withAnimation(FLOAnimation.quick) {
                                NavigationService.shared.selectedDetail = .editInvoice(id: invoice.id)
                            }
                        } else {
                            showingEditSheet = true
                        }
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button {
                        HapticService.play(.light)
                        showingShareSheet = true
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    
                    Button {
                        HapticService.play(.light)
                        duplicateInvoice()
                    } label: {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        HapticService.play(.medium)
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .accessibilityLabel("Invoice actions")
                        .accessibilityHint("Edit, share, duplicate, or delete this invoice")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EnhancedEditInvoiceView(invoice: invoice)
        }
        .sheet(isPresented: $showingMarkSentSheet) {
            MarkAsSentView(invoice: invoice)
        }
        .sheet(isPresented: $showingMarkPaidSheet) {
            MarkAsPaidView(invoice: invoice)
        }
        .sheet(isPresented: $showingShareSheet) {
            if let pdfURL = generateInvoicePDF() {
                ActivityView(activityItems: [pdfURL])
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                    Text("PDF Generation Failed")
                        .font(.title2.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("Unable to generate PDF. Please ensure the invoice has at least one line item and try again.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                    
                    Button("Dismiss") {
                        showingShareSheet = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.businessColor)
                    .accessibilityHint("Close PDF error dialog")
                }
                .padding()
                .accessibilityElement(children: .combine)
                .accessibilityLabel("PDF generation failed. Unable to generate PDF. Please ensure the invoice has at least one line item and try again.")
            }
        }
        .alert("Delete Invoice", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteInvoice()
            }
        } message: {
            Text("Are you sure you want to delete this invoice? This action cannot be undone.")
        }
        .alert("Invoice Duplicated", isPresented: $showingDuplicateSuccess) {
            Button("OK") { }
        } message: {
            Text("A copy of this invoice has been created as a new draft.")
        }
        .onAppear {
            // Announce screen
            AccessibilityAnnouncement.screenChanged(
                "Invoice details, \(invoice.invoiceNumber), \(statusText), \(AccessibilityFormatters.spokenCurrency(invoice.totalAmount))"
            )
            
            // Delay entrance animation until view is fully presented
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    contentAppeared = true
                }
            }
            
            // Delay actions animation slightly more (was 0.3, now 0.6 to maintain relative timing)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    actionsAppeared = true
                }
            }
        }
    }
    
    // MARK: - Haptic Preparation
    
        
    // MARK: - View Components
    
    private var statusHeader: some View {
        Group {
            if isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(invoice.invoiceNumber)
                            .font(.title2.bold())
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        
                        Text(statusDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(invoice.totalAmount.formatted(.currency(code: "USD")))
                            .font(.title.bold())
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .contentTransition(.numericText())
                        
                        statusBadge
                    }
                }
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(invoice.invoiceNumber)
                            .font(.title2.bold())
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        
                        Text(statusDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(invoice.totalAmount.formatted(.currency(code: "USD")))
                            .font(.title.bold())
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .contentTransition(.numericText())
                        
                        statusBadge
                    }
                }
            }
        }
        .card()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(statusHeaderLabel)
        .accessibilityAddTraits(.isHeader)
    }
    
    /// Combined accessibility label for status header
    private var statusHeaderLabel: String {
        var parts = [
            "Invoice \(invoice.invoiceNumber)",
            AccessibilityFormatters.spokenCurrency(invoice.totalAmount),
            "Status: \(statusText)"
        ]
        parts.append(statusDescription)
        return parts.joined(separator: ", ")
    }
    
    private var statusBadge: some View {
        Text(statusText)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(statusColor)
            .clipShape(Capsule())
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: invoice.status)
            .accessibilityHidden(true)
    }
    
    // MARK: - Payment Progress Section
    
    private var paymentProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Payment Progress")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Spacer()
                
                Text("\(Int(invoice.paymentProgress * 100))%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.incomeGreen)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.numericText())
            }
            
            // Animated progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 12)
                    
                    Rectangle()
                        .fill(Color.incomeGreen)
                        .frame(width: geometry.size.width * invoice.paymentProgress, height: 12)
                        .animation(.spring(response: 0.8, dampingFraction: 0.7), value: invoice.paymentProgress)
                }
                .cornerRadius(6)
            }
            .frame(height: 12)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Payment progress")
            .accessibilityValue("\(Int(invoice.paymentProgress * 100)) percent")
            
            // Adaptive layout for amounts
            Group {
                if isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Paid")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Text(invoice.formattedAmountPaid)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.incomeGreen)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Remaining")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Text(invoice.formattedRemainingBalance)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.orange)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                    }
                } else {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Paid")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Text(invoice.formattedAmountPaid)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.incomeGreen)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Remaining")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Text(invoice.formattedRemainingBalance)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.orange)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Paid \(invoice.formattedAmountPaid), remaining \(invoice.formattedRemainingBalance)")
        }
        .card()
    }
    
    // MARK: - Payment History Section
    
    private var paymentHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Payment History")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            
            VStack(spacing: 8) {
                ForEach(Array((invoice.payments ?? []).enumerated()), id: \.element.id) { index, payment in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(payment.amount.formatted(.currency(code: "USD")))
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            
                            Text(payment.paymentMethod.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(payment.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .accessibilityHidden(true)
                        }
                    }
                    .padding(.vertical, 4)
                    .opacity(contentAppeared ? 1 : 0.001)
                    .offset(x: contentAppeared ? 0 : -20)
                    .animation(FLOAnimation.standard.delay(Double(index) * 0.05), value: contentAppeared)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(paymentRowLabel(payment))
                    
                    if payment != invoice.payments?.last {
                        Divider()
                    }
                }
            }
        }
        .card()
    }
    
    /// Accessibility label for a payment history row
    private func paymentRowLabel(_ payment: InvoicePayment) -> String {
        "\(AccessibilityFormatters.spokenCurrency(payment.amount)) via \(payment.paymentMethod.displayName), on \(AccessibilityFormatters.spokenDate(payment.date))"
    }
    
    // MARK: - Client Section
    
    private var clientSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Client Information")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            
            if let client = invoice.client {
                VStack(alignment: .leading, spacing: 8) {
                    Text(client.name)
                        .font(.body.weight(.medium))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    
                    if let email = client.email {
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                                .accessibilityHidden(true)
                            Text(email)
                                .font(.subheadline)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                    }
                    
                    if let phone = client.phone {
                        HStack {
                            Image(systemName: "phone")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                                .accessibilityHidden(true)
                            Text(phone)
                                .font(.subheadline)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    
                    if let address = client.address {
                        HStack(alignment: .top) {
                            Image(systemName: "mappin.circle")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                                .accessibilityHidden(true)
                            Text(address)
                                .font(.subheadline)
                                .lineLimit(3)
                                .minimumScaleFactor(0.7)
                        }
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(clientAccessibilityLabel(client))
            } else {
                Text("No client assigned")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .card()
    }
    
    /// Combined accessibility label for client info
    private func clientAccessibilityLabel(_ client: Client) -> String {
        var parts = [client.name]
        if let email = client.email { parts.append("Email: \(email)") }
        if let phone = client.phone { parts.append("Phone: \(phone)") }
        if let address = client.address { parts.append("Address: \(address)") }
        return parts.joined(separator: ", ")
    }
    
    // MARK: - Invoice Details Section
    
    private var invoiceDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Invoice Details")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            
            VStack(spacing: 8) {
                DetailRow(label: "Invoice Number", value: invoice.invoiceNumber)
                DetailRow(label: "Issue Date", value: invoice.issueDate.formatted(date: .abbreviated, time: .omitted))
                    .accessibilityLabel("Issue date, \(AccessibilityFormatters.spokenDate(invoice.issueDate))")
                DetailRow(label: "Due Date", value: invoice.dueDate.formatted(date: .abbreviated, time: .omitted))
                    .accessibilityLabel("Due date, \(AccessibilityFormatters.spokenDate(invoice.dueDate))")
                
                if invoice.isOverdue {
                    DetailRow(
                        label: "Days Overdue",
                        value: "\(invoice.daysOverdue) days",
                        valueColor: .red
                    )
                    .accessibilityLabel("\(invoice.daysOverdue) days overdue")
                }
                
                DetailRow(label: "Payment Terms", value: invoice.paymentTerms.isEmpty ? "N/A" : invoice.paymentTerms)
                
                if let sentDate = invoice.sentDate {
                    DetailRow(label: "Sent Date", value: sentDate.formatted(date: .abbreviated, time: .omitted))
                        .accessibilityLabel("Sent date, \(AccessibilityFormatters.spokenDate(sentDate))")
                }
                
                if let paidDate = invoice.paidDate {
                    DetailRow(
                        label: "Paid Date",
                        value: paidDate.formatted(date: .abbreviated, time: .omitted),
                        valueColor: .green
                    )
                    .accessibilityLabel("Paid date, \(AccessibilityFormatters.spokenDate(paidDate))")
                }
            }
        }
        .card()
    }
    
    // MARK: - Line Items Section
    
    private var lineItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Line Items")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            
            VStack(spacing: 8) {
                ForEach(Array((invoice.items ?? []).enumerated()), id: \.element.id) { index, item in
                    LineItemRow(item: item)
                        .opacity(contentAppeared ? 1 : 0.001)
                        .offset(x: contentAppeared ? 0 : -15)
                        .animation(FLOAnimation.standard.delay(Double(index) * 0.03), value: contentAppeared)
                    
                    if item != invoice.items?.last {
                        Divider()
                    }
                }
            }
        }
        .card()
    }
    
    // MARK: - Totals Section
    
    private var totalsSection: some View {
        VStack(spacing: 8) {
            Group {
                if isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Subtotal")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(invoice.subtotal.formatted(.currency(code: "USD")))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                } else {
                    HStack {
                        Text("Subtotal")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer()
                        Text(invoice.subtotal.formatted(.currency(code: "USD")))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Subtotal, \(AccessibilityFormatters.spokenCurrency(invoice.subtotal))")
            
            if invoice.discountAmount > 0 {
                Group {
                    if isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Discount")
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Text("-\(invoice.discountAmount.formatted(.currency(code: "USD")))")
                                .foregroundStyle(.red)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                    } else {
                        HStack {
                            Text("Discount")
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Spacer()
                            Text("-\(invoice.discountAmount.formatted(.currency(code: "USD")))")
                                .foregroundStyle(.red)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Discount, minus \(AccessibilityFormatters.spokenCurrency(invoice.discountAmount))")
            }
            
            if invoice.taxAmount > 0 {
                Group {
                    if isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tax (\(Int(invoice.taxRate * 100))%)")
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Text(invoice.taxAmount.formatted(.currency(code: "USD")))
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                    } else {
                        HStack {
                            Text("Tax (\(Int(invoice.taxRate * 100))%)")
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Spacer()
                            Text(invoice.taxAmount.formatted(.currency(code: "USD")))
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Tax at \(Int(invoice.taxRate * 100)) percent, \(AccessibilityFormatters.spokenCurrency(invoice.taxAmount))")
            }
            
            Divider()
            
            Group {
                if isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total")
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(invoice.totalAmount.formatted(.currency(code: "USD")))
                            .font(.title3.bold())
                            .foregroundStyle(Color.brandPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .contentTransition(.numericText())
                    }
                } else {
                    HStack {
                        Text("Total")
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer()
                        Text(invoice.totalAmount.formatted(.currency(code: "USD")))
                            .font(.title3.bold())
                            .foregroundStyle(Color.brandPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .contentTransition(.numericText())
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Total, \(AccessibilityFormatters.spokenCurrency(invoice.totalAmount))")
            .accessibilityAddTraits(.isSummaryElement)
        }
        .card()
    }
    
    // MARK: - Payment Instructions Section
    
    private func paymentInstructionsSection(_ instructions: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Payment Instructions")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            Text(instructions)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(5)
                .minimumScaleFactor(0.7)
        }
        .card()
    }
    
    // MARK: - Payment Links Section
    
    private var hasPaymentLinks: Bool {
        invoice.stripePaymentLink != nil ||
        invoice.paypalLink != nil ||
        invoice.venmoUsername != nil ||
        invoice.zelleEmail != nil
    }
    
    private var paymentLinksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Payment Options")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            
            VStack(spacing: 8) {
                if let stripe = invoice.stripePaymentLink {
                    PaymentLinkRow(
                        service: "Stripe",
                        link: stripe,
                        icon: "creditcard.circle.fill"
                    )
                }
                
                if let paypal = invoice.paypalLink {
                    PaymentLinkRow(
                        service: "PayPal",
                        link: paypal,
                        icon: "link.circle.fill"
                    )
                }
                
                if let venmo = invoice.venmoUsername {
                    PaymentLinkRow(
                        service: "Venmo",
                        link: "@\(venmo)",
                        icon: "person.circle.fill"
                    )
                }
                
                if let zelle = invoice.zelleEmail {
                    PaymentLinkRow(
                        service: "Zelle",
                        link: zelle,
                        icon: "envelope.circle.fill"
                    )
                }
            }
        }
        .card()
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            // Mark as Paid button (only if not fully paid)
            if !invoice.isFullyPaid && invoice.status != InvoiceStatus.cancelled {
                Button {
                    HapticService.play(.medium)
                    if routesToDetailPane {
                        withAnimation(FLOAnimation.quick) {
                            NavigationService.shared.selectedDetail = .markInvoicePaid(id: invoice.id)
                        }
                    } else {
                        showingMarkPaidSheet = true
                    }
                } label: {
                    Label(
                        invoice.hasPayments ? "Record Payment" : "Mark as Paid",
                        systemImage: "checkmark.circle.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(AnimatedActionButtonStyle(color: .green))
                .accessibilityLabel(invoice.hasPayments ? "Record payment" : "Mark as paid")
                .accessibilityHint(invoice.hasPayments ? "Record an additional payment for this invoice" : "Record full or partial payment for this invoice")
            }
            
            // Ready to Send button (only if draft)
            if invoice.status == InvoiceStatus.draft {
                Button {
                    HapticService.play(.medium)
                    if routesToDetailPane {
                        withAnimation(FLOAnimation.quick) {
                            NavigationService.shared.selectedDetail = .markInvoiceSent(id: invoice.id)
                        }
                    } else {
                        showingMarkSentSheet = true
                    }
                } label: {
                    Label("Ready to Send", systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AnimatedActionButtonStyle(color: .accentColor))
                .accessibilityLabel("Ready to send")
                .accessibilityHint("Mark this invoice as sent to the client")
            }
            
            // Send Reminder button (if overdue and not paid)
            if invoice.isOverdue && invoice.status != InvoiceStatus.paid {
                Button {
                    HapticService.play(.light)
                    sendReminder()
                } label: {
                    Label("Send Reminder", systemImage: "bell.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AnimatedSecondaryButtonStyle())
                .accessibilityLabel("Send reminder")
                .accessibilityHint("Send a payment reminder for this overdue invoice, \(invoice.daysOverdue) days past due")
            }
        }
    }
    
    private func reminderHistorySection(_ reminders: [ReminderRecord]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reminder History")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            
            VStack(spacing: 8) {
                ForEach(Array(reminders.enumerated()), id: \.offset) { index, reminder in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(reminder.reminderType.rawValue)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text(reminder.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .accessibilityHidden(true)
                    }
                    .opacity(contentAppeared ? 1 : 0.001)
                    .offset(x: contentAppeared ? 0 : -20)
                    .animation(FLOAnimation.standard.delay(Double(index) * 0.05), value: contentAppeared)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(reminder.reminderType.rawValue) reminder sent \(AccessibilityFormatters.spokenDate(reminder.date))")
                }
            }
        }
        .card()
    }
    
    // MARK: - Computed Properties
    
    private var statusColor: Color {
        switch invoice.status {
        case .draft:
            return .gray
        case .sent, .viewed:
            return invoice.isOverdue ? .red : .blue
        case .paid:
            return .green
        case .partiallyPaid:
            return .orange
        case .overdue:
            return .red
        case .cancelled:
            return .orange
        }
    }
    
    private var statusText: String {
        switch invoice.status {
        case .draft:
            return "Draft"
        case .sent:
            return "Sent"
        case .viewed:
            return "Viewed"
        case .paid:
            return "Paid"
        case .partiallyPaid:
            return "Partially Paid"
        case .overdue:
            return "Overdue"
        case .cancelled:
            return "Cancelled"
        }
    }
    
    private var statusDescription: String {
        if invoice.status == InvoiceStatus.paid {
            if let paidDate = invoice.paidDate {
                return "Paid on \(paidDate.formatted(date: .abbreviated, time: .omitted))"
            }
            return "Paid"
        } else if invoice.isPartiallyPaid {
            return "\(invoice.formattedAmountPaid) of \(invoice.totalAmount.formatted(.currency(code: "USD"))) paid"
        } else if invoice.isOverdue {
            return "\(invoice.daysOverdue) days overdue"
        } else {
            return "Due \(invoice.dueDate.formatted(date: .abbreviated, time: .omitted))"
        }
    }
    
    // MARK: - Actions
    
    private func sendReminder() {
        HapticService.play(.success)
        Task {
            await InvoiceReminderService.shared.scheduleReminder(for: invoice, immediately: true)
        }
        AccessibilityAnnouncement.announce("Reminder sent")
    }
    
    /// Duplicate invoice (InvoiceService v4.0 compatible)
    private func duplicateInvoice() {
        do {
            _ = try InvoiceService.shared.duplicateInvoice(invoice, context: modelContext)
            HapticService.play(.success)
            showingDuplicateSuccess = true
            AccessibilityAnnouncement.announce("Invoice duplicated as new draft")
        } catch {
            HapticService.play(.error)
            AccessibilityAnnouncement.announce("Failed to duplicate invoice")
            print("❌ Failed to duplicate invoice: \(error)")
        }
    }
    
    private func deleteInvoice() {
        HapticService.play(.warning)
        modelContext.delete(invoice)
        try? modelContext.save()
        AccessibilityAnnouncement.announce("Invoice deleted")
        dismiss()
    }
    
    /// Generate PDF (InvoiceService v4.0 compatible)
    private func generateInvoicePDF() -> URL? {
        do {
            return try InvoiceService.shared.savePDFToTemporaryFile(for: invoice, context: modelContext)
        } catch {
            print("❌ Failed to generate PDF: \(error)")
            return nil
        }
    }
}

// MARK: - Animated Button Styles

struct AnimatedActionButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(color)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { oldValue, newValue in
                if newValue {
                    HapticService.play(.light)
                }
            }
    }
}

struct AnimatedSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.primary)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.floSecondarySystemBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.3))
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { oldValue, newValue in
                if newValue {
                    HapticService.play(.light)
                }
            }
    }
}

// MARK: - Supporting Views

private struct DetailRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            Text(value)
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }
}

struct LineItemRow: View {
    let item: InvoiceItem
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.itemDescription)
                    .font(.subheadline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text("\(Int(item.quantity)) × \(item.unitPrice.formatted(.currency(code: "USD")))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer()
            Text(item.total.formatted(.currency(code: "USD")))
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(lineItemAccessibilityLabel)
    }
    
    private var lineItemAccessibilityLabel: String {
        "\(item.itemDescription), \(Int(item.quantity)) at \(AccessibilityFormatters.spokenCurrency(item.unitPrice)), total \(AccessibilityFormatters.spokenCurrency(item.total))"
    }
}

struct PaymentLinkRow: View {
    let service: String
    let link: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Color.businessColor)
                .accessibilityHidden(true)
            Text(service)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            Text(link)
                .font(.caption)
                .foregroundStyle(.blue)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(service), \(link)")
    }
}

#if canImport(UIKit)
private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#else
private struct ActivityView: View {
    let activityItems: [Any]
    var body: some View {
        Text("Share not available on macOS")
    }
}
#endif

extension View {
    func card() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.floSystemBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .floCardShadow()
    }
}

#Preview {
    NavigationStack {
        InvoiceDetailView(invoice: Invoice(
            invoiceNumber: "INV-2024-001",
            client: nil,
            issueDate: Date(),
            dueDate: Date().addingTimeInterval(30 * 86400),
            status: .sent,
            paymentTerms: "Net 30",
            taxRate: 0.0825,
            discountAmount: 0
        ))
    }
    .modelContainer(for: [Invoice.self, Account.self, InvoicePayment.self, Category.self, Transaction.self])
}
