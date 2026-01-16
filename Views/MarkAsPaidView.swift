//  MarkAsPaidView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.0 - Enhanced with Haptics & Micro-Animations
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  Record payments against invoices with account tracking and income transaction creation
//
//  ENHANCEMENTS v2.0:
//  - Haptic feedback on button taps, payment recording, and validation states
//  - Animated payment progress bar with spring physics
//  - Quick amount button press animations with scale effects
//  - Success celebration with confetti-style feedback
//  - Smooth section transitions and loading states
//  - Enhanced status badge animations
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
    @State private var paymentAmount: String = ""
    @State private var paymentDate = Date()
    @State private var paymentMethod: PaymentMethod = .bankTransfer
    @State private var selectedAccount: Account?
    @State private var notes = ""
    
    // Options
    @State private var createTransaction = true
    @State private var selectedCategory: Category?
    
    // UI State
    @State private var isProcessing = false
    @State private var showingSuccess = false
    @State private var showingPartialPaymentInfo = false
    
    // Animation States
    @State private var headerScale: CGFloat = 0.95
    @State private var headerOpacity: Double = 0
    @State private var progressBarAnimated = false
    @State private var showSuccessCheck = false
    @State private var amountFieldShake = false
    
    // Computed Properties
    private var parsedAmount: Double? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current
        return formatter.number(from: paymentAmount)?.doubleValue
    }
    
    private var isValidAmount: Bool {
        guard let amount = parsedAmount else { return false }
        return amount > 0 && amount <= invoice.remainingBalance + 0.01
    }
    
    private var isFullPayment: Bool {
        guard let amount = parsedAmount else { return false }
        return abs(amount - invoice.remainingBalance) < 0.01
    }
    
    private var remainingAfterPayment: Double {
        guard let amount = parsedAmount else { return invoice.remainingBalance }
        return max(invoice.remainingBalance - amount, 0)
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
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        recordPayment()
                    }
                    .disabled(!isValidAmount || isProcessing)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                setupDefaults()
                animateHeader()
            }
            .alert("Payment Recorded!", isPresented: $showingSuccess) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                if isFullPayment {
                    Text("Invoice \(invoice.invoiceNumber) has been paid in full!")
                } else {
                    Text("Payment of \(parsedAmount?.formatted(.currency(code: "USD")) ?? "$0") recorded.\n\nRemaining balance: \(remainingAfterPayment.formatted(.currency(code: "USD")))")
                }
            }
            .sheet(isPresented: $showingPartialPaymentInfo) {
                partialPaymentInfoSheet
            }
        }
    }
    
    // MARK: - Header Animation
    
    private func animateHeader() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            headerScale = 1.0
            headerOpacity = 1.0
        }
        
        // Animate progress bar after header
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
                
                Divider()
                
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
                            .foregroundStyle(Color.brandPrimary)
                    }
                }
                .scaleEffect(headerScale)
                .opacity(headerOpacity)
                
                // Progress bar (if partially paid)
                if invoice.hasPayments {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 8)
                            
                            Rectangle()
                                .fill(Color.incomeGreen)
                                .frame(width: progressBarAnimated ? geometry.size.width * invoice.paymentProgress : 0, height: 8)
                        }
                        .cornerRadius(4)
                    }
                    .frame(height: 8)
                }
            }
            .padding(.vertical, 8)
        }
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
            ForEach(invoice.payments.sorted(by: { $0.date > $1.date })) { payment in
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
                        .foregroundStyle(Color.brandPrimary)
                }
            }
        }
    }
    
    // MARK: - Payment Details Section
    
    private var paymentDetailsSection: some View {
        Section {
            // Amount Field with validation feedback
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("$")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    
                    TextField("0.00", text: $paymentAmount)
                        .font(.title2)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.leading)
                        .offset(x: amountFieldShake ? -5 : 0)
                        .animation(amountFieldShake ? .easeInOut(duration: 0.05).repeatCount(5, autoreverses: true) : .default, value: amountFieldShake)
                }
                
                // Validation indicator
                if parsedAmount != nil {
                    HStack(spacing: 4) {
                        Image(systemName: isValidAmount ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .font(.caption)
                        
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
                    let generator = UISelectionFeedbackGenerator()
                    generator.selectionChanged()
                }
            
            // Payment Method Picker
            Picker("Payment Method", selection: $paymentMethod) {
                ForEach(PaymentMethod.allCases, id: \.self) { method in
                    Label(method.displayName, systemImage: method.icon)
                        .tag(method)
                }
            }
            .onChange(of: paymentMethod) { _, _ in
                let generator = UISelectionFeedbackGenerator()
                generator.selectionChanged()
            }
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
                let generator = UISelectionFeedbackGenerator()
                generator.selectionChanged()
            }
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
                }
            
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
                    let generator = UISelectionFeedbackGenerator()
                    generator.selectionChanged()
                }
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
        }
    }
    
    // MARK: - Partial Payment Info Sheet
    
    private var partialPaymentInfoSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.brandPrimary)
                    .symbolEffect(.bounce, options: .speed(0.5))
                
                Text("About Partial Payments")
                    .font(.title2)
                    .fontWeight(.bold)
                
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
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.incomeGreen)
                .font(.caption)
            Text(text)
        }
    }
    
    // MARK: - Setup & Actions
    
    private func setupDefaults() {
        // Set default amount to remaining balance
        paymentAmount = String(format: "%.2f", invoice.remainingBalance)
        
        // Set default account to primary
        selectedAccount = primaryAccount
        
        // Set default category to first income category (likely "Client Payment")
        selectedCategory = incomeCategories.first { $0.name.contains("Client") || $0.name.contains("Payment") }
            ?? incomeCategories.first
    }
    
    private func recordPayment() {
        guard let amount = parsedAmount, isValidAmount else {
            // Shake animation for invalid amount
            withAnimation(.easeInOut(duration: 0.05).repeatCount(5, autoreverses: true)) {
                amountFieldShake = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                amountFieldShake = false
            }
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            return
        }
        
        isProcessing = true
        
        // Processing haptic
        HapticService.play(.heavy)
        // Create income transaction if requested
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
        
        // Add payment to invoice
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
            
            // Success haptic with celebration feel
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            // Additional impact for "celebration"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                HapticService.play(.heavy)
            }
            
            showingSuccess = true
            
            #if DEBUG
            print("✅ Payment recorded: \(amount.formatted(.currency(code: "USD")))")
            #endif
            
        } catch {
            print("❌ Failed to record payment: \(error)")
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            
            isProcessing = false
        }
    }
}

// MARK: - Quick Amount Button

private struct QuickAmountButton: View {
    let label: String
    let amount: Double
    @Binding var paymentAmount: String
    
    @State private var isPressed = false
    
    var body: some View {
        Button {
            HapticService.play(.medium)
            
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isPressed = true
            }
            
            paymentAmount = String(format: "%.2f", amount)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    isPressed = false
                }
            }
        } label: {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.brandPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.brandPrimary.opacity(0.1))
                )
                .scaleEffect(isPressed ? 0.92 : 1.0)
        }
        .buttonStyle(.plain)
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
    invoice.items.append(item)
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
    invoice.items.append(item)
    
    // Add existing payment
    let existingPayment = InvoicePayment(
        amount: 5000,
        date: Date().addingTimeInterval(-86400 * 7),
        paymentMethod: .bankTransfer,
        notes: "50% deposit"
    )
    existingPayment.invoice = invoice
    invoice.payments.append(existingPayment)
    
    context.insert(invoice)
    
    let account = Account(name: "Chase Business", accountType: .checking, isPrimary: true)
    context.insert(account)
    
    return MarkAsPaidView(invoice: invoice)
        .modelContainer(container)
}
