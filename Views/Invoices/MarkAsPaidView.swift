//  MarkAsPaidView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.4 - Penny-Up Currency Input
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v2.4 - Penny-Up Currency Input:
//  ✅ REPLACED: Old TextField + String paymentAmount with CurrencyInputField component
//  ✅ CHANGED: paymentAmount state from String to Double
//  ✅ REMOVED: parsedAmount computed property (String parsing no longer needed)
//  ✅ UPDATED: isValidAmount, isFullPayment, remainingAfterPayment to use Double directly
//  ✅ UPDATED: QuickAmountButton binding from String to Double
//  ✅ UPDATED: setupDefaults(), recordPayment() to use Double directly
//
//  CHANGES v2.2:
//  ✅ ADDED: Invoice summary header accessible (number, client, status combined)
//  ✅ ADDED: Amount totals accessible with spoken currency
//  ✅ ADDED: Payment progress bar accessible with percentage
//  ✅ ADDED: Status badge accessible (decorative visuals hidden)
//  ✅ ADDED: Payment history rows accessible (date, method, amount combined)
//  ✅ ADDED: Payment history info button labeled
//  ✅ ADDED: Payment amount field labeled with validation state
//  ✅ ADDED: Quick amount buttons accessible with spoken dollar amounts
//  ✅ ADDED: Payment date/method pickers with spoken values
//  ✅ ADDED: Deposit account picker labeled
//  ✅ ADDED: Create income transaction toggle with hint
//  ✅ ADDED: Category picker accessible
//  ✅ ADDED: Notes field labeled
//  ✅ ADDED: Cancel/Save toolbar buttons with dynamic hints
//  ✅ ADDED: Screen change announcement on appear
//  ✅ ADDED: Payment success/failure announced
//  ✅ ADDED: Partial payment info sheet accessible
//  ✅ ADDED: Decorative icons hidden throughout
//
//  CHANGES v2.1:
//  - Migrated to centralized HapticService
//

import SwiftUI
import SwiftData

struct MarkAsPaidView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(filter: #Predicate<Account> { $0.isActive }, sort: \Account.name) private var accounts: [Account]
    @Query(filter: #Predicate<Category> { $0.isIncome }, sort: \Category.name) private var incomeCategories: [Category]
    
    let invoice: Invoice
    
    // Payment Details
    @State private var paymentAmount: Double = 0
    @State private var paymentDate = Date()
    @State private var paymentMethod: PaymentMethod = .bankTransfer
    @State private var selectedAccount: Account?
    @State private var notes = ""
    
    // Options
    @State private var createTransaction = true
    @State private var selectedCategory: Category?
    
    // UI State
    @State private var isProcessing = false
    @State private var showCelebration = false
    @State private var showingPartialPaymentInfo = false
    
    // Animation States
    @State private var headerScale: CGFloat = 0.95
    @State private var headerOpacity: Double = 0
    @State private var progressBarAnimated = false
    @State private var showSuccessCheck = false
    @State private var amountFieldShake = false
    
    // Computed Properties
    private var isValidAmount: Bool {
        paymentAmount > 0 && paymentAmount <= invoice.remainingBalance + 0.01
    }

    private var isFullPayment: Bool {
        abs(paymentAmount - invoice.remainingBalance) < 0.01
    }

    private var remainingAfterPayment: Double {
        guard paymentAmount > 0 else { return invoice.remainingBalance }
        return max(invoice.remainingBalance - paymentAmount, 0)
    }
    
    private var primaryAccount: Account? {
        accounts.first { $0.isPrimary } ?? accounts.first
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Invoice Summary Section
                invoiceSummarySection
                
                // Payment History (if any)
                if invoice.hasPayments {
                    paymentHistorySection
                }
                
                // Payment Details Section
                paymentDetailsSection
                
                // Account Section
                accountSection
                
                // Income Transaction Section
                incomeTransactionSection
                
                // Notes Section
                notesSection
            }
            .navigationTitle("Record Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticService.play(.heavy)
                        dismiss()
                    }
                    // v2.2: VoiceOver
                    .accessibilityLabel("Cancel")
                    .accessibilityHint("Double tap to go back without recording payment")
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        recordPayment()
                    }
                    .disabled(!isValidAmount || isProcessing)
                    .fontWeight(.semibold)
                    // v2.2: VoiceOver
                    .accessibilityLabel("Save payment")
                    .accessibilityHint(saveButtonHint)
                }
            }
            .onAppear {
                setupDefaults()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    animateHeader()
                }
                // v2.2: Announce screen
                AccessibilityAnnouncement.screenChanged("Record Payment for \(invoice.invoiceNumber). Remaining balance: \(AccessibilityFormatters.spokenCurrency(invoice.remainingBalance))")
            }
            .sheet(isPresented: $showingPartialPaymentInfo) {
                partialPaymentInfoSheet
            }
            .celebrationOverlay(
                isPresented: $showCelebration,
                style: .invoicePaid,
                amount: paymentAmount > 0 ? paymentAmount : nil,
                message: isFullPayment ? "Paid in Full!" : "Payment Recorded",
                onDismiss: {
                    dismiss()
                }
            )
        }
    }
    
    // v2.2: Dynamic save button hint
    private var saveButtonHint: String {
        if isProcessing {
            return "Processing payment"
        } else if paymentAmount <= 0 {
            return "Enter a payment amount to enable saving"
        } else if !isValidAmount {
            return "Amount exceeds remaining balance"
        } else if isFullPayment {
            return "Double tap to record full payment"
        } else {
            return "Double tap to record partial payment"
        }
    }
    
    // MARK: - Header Animation
    
    private func animateHeader() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            headerScale = 1.0
            headerOpacity = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                progressBarAnimated = true
            }
        }
    }
    
    // MARK: - Invoice Summary Section
    
    private var invoiceSummarySection: some View {
        Section {
            VStack(spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(invoice.invoiceNumber)
                            .font(.headline)
                        
                        if let clientName = invoice.client?.name {
                            Text(clientName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    invoiceStatusBadge
                }
                .scaleEffect(headerScale)
                .opacity(headerOpacity)
                // v2.2: Combined header label
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(invoice.invoiceNumber), \(invoice.client?.name ?? "No client"), Status: \(invoice.status.displayName)")
                
                Divider()
                    .accessibilityHidden(true)
                
                // Amounts
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(invoice.totalAmount.formatted(.currency(code: "USD")))
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    if invoice.hasPayments {
                        VStack(alignment: .center, spacing: 4) {
                            Text("Paid")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(invoice.amountPaid.formatted(.currency(code: "USD")))
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.incomeGreen)
                        }
                        
                        Spacer()
                    }
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Remaining")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(invoice.remainingBalance.formatted(.currency(code: "USD")))
                            .font(.title3)
                            .fontWeight(.bold)
                             .foregroundStyle(Color.brandPrimaryText)
                    }
                }
                .scaleEffect(headerScale)
                .opacity(headerOpacity)
                // v2.2: Combined amounts label
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(amountsSummaryLabel)
                .accessibilityAddTraits(.isSummaryElement)
                
                // Progress bar (if partially paid)
                if invoice.hasPayments {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.primary.opacity(0.1))
                                .frame(height: 8)
                            
                            Rectangle()
                                .fill(Color.incomeGreen)
                                .frame(width: progressBarAnimated ? geometry.size.width * invoice.paymentProgress : 0, height: 8)
                        }
                        .cornerRadius(4)
                    }
                    .frame(height: 8)
                    // v2.2: Progress bar accessible
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Payment progress: \(Int(invoice.paymentProgress * 100)) percent paid")
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // v2.2: Amounts summary for VoiceOver
    private var amountsSummaryLabel: String {
        var parts = ["Invoice total: \(AccessibilityFormatters.spokenCurrency(invoice.totalAmount))"]
        if invoice.hasPayments {
            parts.append("Paid: \(AccessibilityFormatters.spokenCurrency(invoice.amountPaid))")
        }
        parts.append("Remaining: \(AccessibilityFormatters.spokenCurrency(invoice.remainingBalance))")
        return parts.joined(separator: ", ")
    }
    
    private var invoiceStatusBadge: some View {
        Text(invoice.status.displayName)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor)
            .clipShape(Capsule())
            .scaleEffect(headerScale)
            // v2.2: Status handled by parent element
            .accessibilityHidden(true)
    }
    
    private var statusColor: Color {
        switch invoice.status {
        case .draft: return .gray
        case .sent: return .blue
        case .viewed: return .purple
        case .partiallyPaid: return .orange
        case .paid: return .green
        case .overdue: return .red
        case .cancelled: return .gray
        }
    }
    
    // MARK: - Payment History Section
    
    private var paymentHistorySection: some View {
        Section {
            ForEach((invoice.payments ?? []).sorted(by: { $0.date > $1.date })) { payment in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(payment.date.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(payment.paymentMethod.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(payment.amount.formatted(.currency(code: "USD")))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.incomeGreen)
                }
                .padding(.vertical, 4)
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
                // v2.2: Payment row accessible
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Payment on \(AccessibilityFormatters.spokenDate(payment.date)), \(payment.paymentMethod.displayName), \(AccessibilityFormatters.spokenCurrency(payment.amount))")
            }
        } header: {
            HStack {
                Text("Payment History")
                Spacer()
                Button {
                    HapticService.play(.medium)
                    showingPartialPaymentInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.caption)
                         .foregroundStyle(Color.brandPrimaryText)
                }
                // v2.2: VoiceOver
                .accessibilityLabel("About partial payments")
                .accessibilityHint("Double tap to learn about partial payment tracking")
            }
        }
    }
    
    // MARK: - Payment Details Section
    
    private var paymentDetailsSection: some View {
        Section {
            // Amount Field with validation feedback
            VStack(alignment: .leading, spacing: 8) {
                CurrencyInputField(
                    amount: $paymentAmount,
                    accessibilityLabelText: "Payment amount"
                )
                .offset(x: amountFieldShake ? -5 : 0)
                .animation(amountFieldShake ? .easeInOut(duration: 0.05).repeatCount(5, autoreverses: true) : .default, value: amountFieldShake)
                
                // Validation indicator
                if paymentAmount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: isValidAmount ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .font(.caption)
                            // v2.2: Decorative (text conveys status)
                            .accessibilityHidden(true)
                        
                        Text(isValidAmount ?
                             (isFullPayment ? "Full payment" : "Partial payment - \(remainingAfterPayment.formatted(.currency(code: "USD"))) remaining") :
                             "Amount exceeds remaining balance")
                            .font(.caption)
                    }
                    .foregroundStyle(isValidAmount ? .green : .red)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            
            // Quick Amount Buttons
            HStack(spacing: 12) {
                QuickAmountButton(
                    label: "25%",
                    amount: invoice.remainingBalance * 0.25,
                    paymentAmount: $paymentAmount
                )
                
                QuickAmountButton(
                    label: "50%",
                    amount: invoice.remainingBalance * 0.50,
                    paymentAmount: $paymentAmount
                )
                
                QuickAmountButton(
                    label: "Full",
                    amount: invoice.remainingBalance,
                    paymentAmount: $paymentAmount
                )
            }
            .padding(.vertical, 4)
            
            // Date Picker
            DatePicker("Payment Date", selection: $paymentDate, displayedComponents: .date)
                .onChange(of: paymentDate) { _, _ in
                    HapticService.shared.selection()
                }
                // v2.2: VoiceOver
                .accessibilityValue(AccessibilityFormatters.spokenDate(paymentDate))
            
            // Payment Method Picker
            Picker("Payment Method", selection: $paymentMethod) {
                ForEach(PaymentMethod.allCases, id: \.self) { method in
                    Label(method.displayName, systemImage: method.icon)
                        .tag(method)
                }
            }
            .onChange(of: paymentMethod) { _, _ in
                HapticService.shared.selection()
            }
            // v2.2: VoiceOver
            .accessibilityValue(paymentMethod.displayName)
        } header: {
            Text("Payment Details")
        }
    }
    
    // MARK: - Account Section
    
    private var accountSection: some View {
        Section {
            Picker("Deposit Account", selection: $selectedAccount) {
                Text("None").tag(Account?.none)
                
                ForEach(accounts) { account in
                    HStack {
                        Image(systemName: account.accountType.icon)
                        Text(account.name)
                    }
                    .tag(Optional(account))
                }
            }
            .onChange(of: selectedAccount) { _, _ in
                HapticService.shared.selection()
            }
            // v2.2: VoiceOver
            .accessibilityLabel("Deposit account")
            .accessibilityValue(selectedAccount?.name ?? "None")
        } header: {
            Text("Deposit To")
        } footer: {
            Text("Select where this payment will be deposited")
        }
    }
    
    // MARK: - Income Transaction Section
    
    private var incomeTransactionSection: some View {
        Section {
            Toggle("Create Income Transaction", isOn: $createTransaction)
                .tint(Color.brandPrimary)
                .onChange(of: createTransaction) { _, newValue in
                    HapticService.play(.medium)
                    // v2.2: Announce toggle change
                    AccessibilityAnnouncement.announce(newValue ? "Income transaction will be created" : "Income transaction will not be created")
                }
                // v2.2: VoiceOver
                .accessibilityHint("When enabled, an income transaction is automatically added to your ledger")
            
            if createTransaction {
                Picker("Category", selection: $selectedCategory) {
                    Text("None").tag(Category?.none)
                    
                    ForEach(incomeCategories) { category in
                        Label(category.name, systemImage: category.icon)
                            .tag(Optional(category))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .onChange(of: selectedCategory) { _, _ in
                    HapticService.shared.selection()
                }
                // v2.2: VoiceOver
                .accessibilityLabel("Income category")
                .accessibilityValue(selectedCategory?.name ?? "None")
            }
        } header: {
            Text("Bookkeeping")
        } footer: {
            if createTransaction {
                Text("An income transaction will be created automatically, linked to this invoice")
            } else {
                Text("Payment will be recorded but won't appear in your transactions")
            }
        }
        .animation(.easeInOut(duration: 0.2), value: createTransaction)
    }
    
    // MARK: - Notes Section
    
    private var notesSection: some View {
        Section("Notes (Optional)") {
            TextField("Check #, reference, etc.", text: $notes, axis: .vertical)
                .lineLimit(2...4)
                // v2.2: VoiceOver
                .accessibilityLabel("Payment notes")
                .accessibilityHint("Optional. Add check number, reference, or other details")
        }
    }
    
    // MARK: - Partial Payment Info Sheet
    
    private var partialPaymentInfoSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "info.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color.brandPrimary)
                    .symbolEffect(.bounce, options: .speed(0.5))
                    // v2.2: Decorative
                    .accessibilityHidden(true)
                
                Text("About Partial Payments")
                    .font(.title2)
                    .fontWeight(.bold)
                    // v2.2: Header trait
                    .accessibilityAddTraits(.isHeader)
                
                Text("FLO supports recording multiple payments against a single invoice. This is useful when:")
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading, spacing: 12) {
                    bulletPoint("Clients pay in installments")
                    bulletPoint("Deposits are collected upfront")
                    bulletPoint("Payments are split across methods")
                }
                
                Text("The invoice will automatically update to 'Partially Paid' until the full balance is received, then change to 'Paid'.")
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Partial Payments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        HapticService.play(.medium)
                        showingPartialPaymentInfo = false
                    }
                    // v2.2: VoiceOver
                    .accessibilityLabel("Done")
                }
            }
            // v2.2: Announce screen
            .onAppear {
                AccessibilityAnnouncement.screenChanged("About Partial Payments")
            }
        }
        .presentationDetents([.medium])
    }
    
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.incomeGreen)
                .font(.caption)
                // v2.2: Decorative
                .accessibilityHidden(true)
            Text(text)
        }
    }
    
    // MARK: - Setup & Actions
    
    private func setupDefaults() {
        paymentAmount = invoice.remainingBalance
        selectedAccount = primaryAccount
        selectedCategory = incomeCategories.first { $0.name.contains("Client") || $0.name.contains("Payment") }
            ?? incomeCategories.first
    }
    
    private func recordPayment() {
        let amount = paymentAmount
        guard isValidAmount else {
            withAnimation(.easeInOut(duration: 0.05).repeatCount(5, autoreverses: true)) {
                amountFieldShake = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                amountFieldShake = false
            }
            
            HapticService.shared.error()
            // v2.2: Announce error
            AccessibilityAnnouncement.announce("Invalid amount. Please enter an amount within the remaining balance.")
            return
        }
        
        isProcessing = true
        
        HapticService.play(.heavy)
        
        var linkedTransaction: Transaction? = nil
        
        if createTransaction {
            let transaction = Transaction(
                amount: amount,
                date: paymentDate,
                note: "Payment for \(invoice.invoiceNumber)",
                isIncome: true,
                merchantName: invoice.client?.name ?? "Client Payment",
                category: selectedCategory,
                financeType: .business,
                hasReceipt: false
            )
            
            modelContext.insert(transaction)
            linkedTransaction = transaction
        }
        
        invoice.addPayment(
            amount: amount,
            date: paymentDate,
            paymentMethod: paymentMethod,
            account: selectedAccount,
            notes: notes,
            linkedTransaction: linkedTransaction
        )
        
        do {
            try modelContext.save()
            
            // v2.2: Announce success
            if isFullPayment {
                AccessibilityAnnouncement.announce("Payment recorded. Invoice \(invoice.invoiceNumber) paid in full.")
            } else {
                AccessibilityAnnouncement.announce("Payment of \(AccessibilityFormatters.spokenCurrency(amount)) recorded. \(AccessibilityFormatters.spokenCurrency(remainingAfterPayment)) remaining.")
            }
            
            // Show celebration overlay (replaces success alert)
            showCelebration = true
            
            #if DEBUG
            print("✅ Payment recorded: \(amount.formatted(.currency(code: "USD")))")
            #endif
            
        } catch {
            print("Failed to record payment: \(error)")
            
            HapticService.shared.error()
            AccessibilityAnnouncement.announce("Failed to record payment")
            
            isProcessing = false
        }
    }
}

// MARK: - Quick Amount Button

private struct QuickAmountButton: View {
    let label: String
    let amount: Double
    @Binding var paymentAmount: Double

    @State private var isPressed = false

    var body: some View {
        Button {
            HapticService.play(.medium)

            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isPressed = true
            }

            paymentAmount = amount

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    isPressed = false
                }
            }
        } label: {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                 .foregroundStyle(Color.brandPrimaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.brandPrimary.opacity(0.1))
                )
                .scaleEffect(isPressed ? 0.92 : 1.0)
        }
        .buttonStyle(.plain)
        // v2.2: VoiceOver
        .accessibilityLabel("\(label) payment: \(AccessibilityFormatters.spokenCurrency(amount))")
        .accessibilityHint("Double tap to set payment amount to \(AccessibilityFormatters.spokenCurrency(amount))")
    }
}

// MARK: - Preview

#Preview("Full Payment") {
    let container = try! ModelContainer(
        for: Invoice.self, Client.self, InvoiceItem.self, Account.self, InvoicePayment.self, Category.self, Transaction.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    let context = container.mainContext
    
    let client = Client(name: "Acme Corporation", email: "billing@acme.com")
    context.insert(client)
    
    let invoice = Invoice(
        invoiceNumber: "INV-2026-001",
        client: client,
        issueDate: Date(),
        dueDate: Calendar.current.date(byAdding: .day, value: 15, to: Date())!,
        status: .sent
    )
    
    let item = InvoiceItem(
        invoice: invoice,
        itemDescription: "Website Design",
        quantity: 1,
        unitPrice: 5000
    )
    invoice.items = [item]
    context.insert(invoice)

    let account = Account(name: "Chase Business", accountType: .checking, isPrimary: true)
    context.insert(account)

    let category = Category(name: "Client Payment", icon: "dollarsign.circle.fill", colorHex: "#14B8A6", isIncome: true)
    context.insert(category)

    return MarkAsPaidView(invoice: invoice)
        .modelContainer(container)
}

#Preview("Partial Payment") {
    let container = try! ModelContainer(
        for: Invoice.self, Client.self, InvoiceItem.self, Account.self, InvoicePayment.self, Category.self, Transaction.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let context = container.mainContext

    let client = Client(name: "TechStart Inc", email: "ap@techstart.com")
    context.insert(client)

    let invoice = Invoice(
        invoiceNumber: "INV-2026-002",
        client: client,
        issueDate: Date().addingTimeInterval(-86400 * 14),
        dueDate: Date().addingTimeInterval(86400),
        status: .partiallyPaid
    )

    let item = InvoiceItem(
        invoice: invoice,
        itemDescription: "Mobile App Development",
        quantity: 1,
        unitPrice: 10000
    )
    invoice.items = [item]

    let existingPayment = InvoicePayment(
        amount: 5000,
        date: Date().addingTimeInterval(-86400 * 7),
        paymentMethod: .bankTransfer,
        notes: "50% deposit"
    )
    existingPayment.invoice = invoice
    invoice.payments = [existingPayment]

    context.insert(invoice)

    let account = Account(name: "Chase Business", accountType: .checking, isPrimary: true)
    context.insert(account)

    return MarkAsPaidView(invoice: invoice)
        .modelContainer(container)
}
