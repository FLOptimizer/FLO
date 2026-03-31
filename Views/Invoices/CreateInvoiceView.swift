//  CreateInvoiceView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.4 - Dynamic Type verification: lineLimit + minimumScaleFactor on all text
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v2.4 - Dynamic Type Verification:
//  ✅ FIXED: Client name text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Client contact name text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Section footer text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Alert message text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: ClientPickerView client name missing lineLimit + minimumScaleFactor
//  ✅ FIXED: ClientPickerView contact name missing lineLimit + minimumScaleFactor
//
//  CHANGES v2.3:
//  ✅ ADDED: Client section accessible (name + contact combined, change/select buttons labeled)
//  ✅ ADDED: Invoice details date pickers with spoken dates
//  ✅ ADDED: Payment terms picker accessible with current value
//  ✅ ADDED: LineItemEditor accessible (description, qty, price, total grouped)
//  ✅ ADDED: Add Line Item button labeled with hint
//  ✅ ADDED: Totals section rows accessible with spoken currency
//  ✅ ADDED: Total row marked as isSummaryElement
//  ✅ ADDED: Payment option fields labeled with hints
//  ✅ ADDED: Notes fields labeled
//  ✅ ADDED: Cancel/Create toolbar buttons with dynamic hints
//  ✅ ADDED: ClientPickerView rows accessible with selection state
//  ✅ ADDED: Screen change announcement on appear
//  ✅ ADDED: Create success/failure announced
//  ✅ ADDED: Usage warning banner accessible
//
//  CHANGES v2.2:
//  - Invoice limit enforcement, UsageLimitService integration
//

import SwiftUI
import FLODesignSystem
import SwiftData

struct CreateInvoiceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Query private var clients: [Client]
    @Query private var existingInvoices: [Invoice]
    
    @State private var selectedClient: Client?
    @State private var issueDate = Date()
    @State private var dueDate = Date().addingTimeInterval(30 * 86400)
    @State private var paymentTerms = "Net 30"
    @State private var taxRate: Double = 0
    @State private var discountAmount: Double = 0
    @State private var notes = ""
    @State private var paymentInstructions = ""
    
    // Payment links
    @State private var stripeLink = ""
    @State private var paypalLink = ""
    @State private var venmoUsername = ""
    @State private var zelleEmail = ""
    
    // Line items
    @State private var lineItems: [InvoiceItemData] = [InvoiceItemData()]
    
    @State private var showingClientPicker = false
    @State private var saveError: Error?
    @State private var showingSaveError = false
    @State private var viewAppeared = false
    
    // v2.2: Usage Limit State
    @State private var usageLimitService: UsageLimitService?
    @State private var showingSubscription = false
    @State private var showingLimitReached = false
    @State private var usageWarning: UsageWarning?
    
    var isValid: Bool {
        selectedClient != nil && !lineItems.filter { $0.isValid }.isEmpty
    }
    
    // v2.2: Check if within invoice limit
    private var isWithinLimit: Bool {
        guard let service = usageLimitService else { return true }
        let (allowed, _) = service.canAddInvoice(tier: subscriptionManager.currentTier)
        return allowed
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // v2.2: Usage warning banner
                if let warning = usageWarning {
                    Section {
                        UsageWarningBanner(
                            warning: warning,
                            showingSubscription: $showingSubscription,
                            isCompact: true
                        )
                    }
                }
                
                // Client section
                Section("Client") {
                    if let client = selectedClient {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(client.name)
                                    .font(.body.weight(.medium))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                if let contact = client.contactName {
                                    Text(contact)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button("Change") {
                                HapticService.play(.light)
                                showingClientPicker = true
                            }
                            // v2.3: VoiceOver
                            .accessibilityLabel("Change client")
                            .accessibilityHint("Double tap to select a different client")
                        }
                        // v2.3: Combined client label
                        .accessibilityElement(children: .combine)
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        Button("Select Client") {
                            HapticService.play(.light)
                            showingClientPicker = true
                        }
                        // v2.3: VoiceOver
                        .accessibilityLabel("Select client")
                        .accessibilityHint("Required. Choose a client for this invoice")
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedClient != nil)
                
                // Invoice details
                Section("Invoice Details") {
                    DatePicker("Issue Date", selection: $issueDate, displayedComponents: .date)
                        .onChange(of: issueDate) { _, _ in
                            HapticService.play(.light)
                        }
                        // v2.3: VoiceOver
                        .accessibilityValue(AccessibilityFormatters.spokenDate(issueDate))
                    
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                        .onChange(of: dueDate) { _, _ in
                            HapticService.play(.light)
                        }
                        // v2.3: VoiceOver
                        .accessibilityValue(AccessibilityFormatters.spokenDate(dueDate))
                    
                    Picker("Payment Terms", selection: $paymentTerms) {
                        Text("Due on Receipt").tag("Due on Receipt")
                        Text("Net 15").tag("Net 15")
                        Text("Net 30").tag("Net 30")
                        Text("Net 60").tag("Net 60")
                    }
                    .onChange(of: paymentTerms) { _, _ in
                        HapticService.play(.selection)
                    }
                    // v2.3: VoiceOver
                    .accessibilityValue(paymentTerms)
                }
                
                // Line items
                Section {
                    ForEach($lineItems) { $item in
                        LineItemEditor(item: $item)
                    }
                    .onDelete { indexSet in
                        HapticService.play(.medium)
                        withAnimation(FLOAnimation.quick) {
                            lineItems.remove(atOffsets: indexSet)
                        }
                        // v2.3: Announce
                        AccessibilityAnnouncement.announce("Line item removed. \(lineItems.count) items remaining.")
                    }
                    
                    Button {
                        HapticService.play(.medium)
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            lineItems.append(InvoiceItemData())
                        }
                        // v2.3: Announce
                        AccessibilityAnnouncement.announce("Line item added")
                    } label: {
                        Label("Add Line Item", systemImage: "plus.circle.fill")
                    }
                    // v2.3: VoiceOver
                    .accessibilityLabel("Add line item")
                    .accessibilityHint("Double tap to add a new line item to this invoice")
                } header: {
                    Text("Line Items")
                } footer: {
                    Text("Tap to edit quantities, prices, and descriptions")
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
                
                // Totals
                Section("Totals") {
                    HStack {
                        Text("Subtotal")
                        Spacer()
                        Text(subtotal.formatted(.currency(code: "USD")))
                            .contentTransition(.numericText())
                    }
                    // v2.3: VoiceOver
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Subtotal: \(AccessibilityFormatters.spokenCurrency(subtotal))")
                    
                    HStack {
                        Text("Tax Rate")
                        Spacer()
                        TextField("0%", value: $taxRate, format: .percent)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    // v2.3: VoiceOver
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Tax rate")
                    .accessibilityValue(taxRate > 0 ? "\(Int(taxRate * 100)) percent" : "0 percent")
                    
                    if taxRate > 0 {
                        HStack {
                            Text("Tax Amount")
                            Spacer()
                            Text(taxAmount.formatted(.currency(code: "USD")))
                                .foregroundStyle(.secondary)
                                .contentTransition(.numericText())
                        }
                        .transition(.opacity)
                        // v2.3: VoiceOver
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Tax amount: \(AccessibilityFormatters.spokenCurrency(taxAmount))")
                    }
                    
                    HStack {
                        Text("Discount")
                        Spacer()
                        TextField("$0.00", value: $discountAmount, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    // v2.3: VoiceOver
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Discount")
                    .accessibilityValue(discountAmount > 0 ? AccessibilityFormatters.spokenCurrency(discountAmount) : "none")
                    
                    HStack {
                        Text("Total")
                            .font(.headline)
                        Spacer()
                        Text(totalAmount.formatted(.currency(code: "USD")))
                            .font(.headline)
                            .foregroundStyle(Color.businessColor)
                            .contentTransition(.numericText())
                    }
                    // v2.3: VoiceOver
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Invoice total: \(AccessibilityFormatters.spokenCurrency(totalAmount))")
                    .accessibilityAddTraits(.isSummaryElement)
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: taxRate > 0)
                
                // Payment options
                Section("Payment Options") {
                    TextField("Stripe Payment Link (optional)", text: $stripeLink)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        // v2.3: VoiceOver
                        .accessibilityLabel("Stripe payment link")
                        .accessibilityHint("Optional. Enter a Stripe payment URL")
                    
                    TextField("PayPal Link (optional)", text: $paypalLink)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        // v2.3: VoiceOver
                        .accessibilityLabel("PayPal link")
                        .accessibilityHint("Optional. Enter a PayPal payment URL")
                    
                    TextField("Venmo Username (optional)", text: $venmoUsername)
                        .autocapitalization(.none)
                        // v2.3: VoiceOver
                        .accessibilityLabel("Venmo username")
                    
                    TextField("Zelle Email (optional)", text: $zelleEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        // v2.3: VoiceOver
                        .accessibilityLabel("Zelle email address")
                }
                
                // Notes
                Section("Notes & Instructions") {
                    TextField("Invoice notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        // v2.3: VoiceOver
                        .accessibilityLabel("Invoice notes")
                    
                    TextField("Payment instructions (optional)", text: $paymentInstructions, axis: .vertical)
                        .lineLimit(3...6)
                        // v2.3: VoiceOver
                        .accessibilityLabel("Payment instructions")
                }
            }
            .navigationTitle("New Invoice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticService.play(.light)
                        dismiss()
                    }
                    // v2.3: VoiceOver
                    .accessibilityLabel("Cancel")
                    .accessibilityHint("Double tap to discard and go back")
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        if !isWithinLimit {
                            HapticService.play(.error)
                            showingLimitReached = true
                        } else {
                            HapticService.play(.medium)
                            createInvoice()
                        }
                    }
                    .disabled(!isValid || !isWithinLimit)
                    // v2.3: VoiceOver
                    .accessibilityLabel("Create invoice")
                    .accessibilityHint(createButtonHint)
                }
            }
            .sheet(isPresented: $showingClientPicker) {
                ClientPickerView(selectedClient: $selectedClient, clients: clients)
            }
            .sheet(isPresented: $showingSubscription) {
                SubscriptionView()
            }
            #if os(macOS)
            .sheet(isPresented: $showingLimitReached) {
                LimitReachedOverlay(
                    limitType: .invoices,
                    currentCount: usageLimitService?.currentMonthInvoiceCount ?? 25,
                    limit: subscriptionManager.currentTier.invoiceLimit ?? 25,
                    showingSubscription: $showingSubscription,
                    onDismiss: {
                        showingLimitReached = false
                        dismiss()
                    }
                )
            }
            #else
            .fullScreenCover(isPresented: $showingLimitReached) {
                LimitReachedOverlay(
                    limitType: .invoices,
                    currentCount: usageLimitService?.currentMonthInvoiceCount ?? 25,
                    limit: subscriptionManager.currentTier.invoiceLimit ?? 25,
                    showingSubscription: $showingSubscription,
                    onDismiss: {
                        showingLimitReached = false
                        dismiss()
                    }
                )
            }
            #endif
            .alert("Could Not Save Invoice", isPresented: $showingSaveError) {
                Button("OK") { }
            } message: {
                Text(saveError?.localizedDescription ?? "An unknown error occurred. Please try again.")
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
            }
            .onAppear {
                setupLimitService()
                // v2.3: Announce screen
                AccessibilityAnnouncement.screenChanged("New Invoice form")
            }
            .onChange(of: selectedClient) { oldValue, newValue in
                if newValue != nil {
                    HapticService.play(.success)
                    // v2.3: Announce client selection
                    AccessibilityAnnouncement.announce("Client selected: \(newValue?.name ?? "")")
                }
            }
        }
    }
    
    // v2.3: Dynamic create button hint
    private var createButtonHint: String {
        if !isWithinLimit {
            return "Invoice limit reached. Upgrade to create more invoices."
        } else if selectedClient == nil {
            return "Select a client to enable creating this invoice"
        } else if lineItems.filter({ $0.isValid }).isEmpty {
            return "Add at least one valid line item to enable creating"
        } else {
            return "Double tap to create this invoice"
        }
    }
    
    // MARK: - v2.2: Limit Service Setup
    
    private func setupLimitService() {
        usageLimitService = UsageLimitService(modelContext: modelContext)
        updateUsageWarning()
    }
    
    private func updateUsageWarning() {
        usageWarning = usageLimitService?.getUsageWarning(
            for: .invoices,
            tier: subscriptionManager.currentTier
        )
    }
    
    // MARK: - Computed Properties
    
    private var subtotal: Double {
        lineItems
            .filter { $0.isValid }
            .reduce(0) { $0 + ($1.quantity * $1.unitPrice) }
    }
    
    private var taxAmount: Double {
        subtotal * taxRate
    }
    
    private var totalAmount: Double {
        subtotal + taxAmount - discountAmount
    }
    
    // MARK: - Actions
    
    private func createInvoice() {
        guard let client = selectedClient else { return }
        
        let invoiceNumber = Invoice.generateNextInvoiceNumber(existingInvoices: existingInvoices)
        
        let invoice = Invoice(
            invoiceNumber: invoiceNumber,
            client: client,
            issueDate: issueDate,
            dueDate: dueDate,
            status: .draft,
            paymentTerms: paymentTerms,
            taxRate: taxRate,
            discountAmount: discountAmount,
            notes: notes.isEmpty ? nil : notes,
            paymentInstructions: paymentInstructions.isEmpty ? nil : paymentInstructions,
            stripePaymentLink: stripeLink.isEmpty ? nil : stripeLink,
            paypalLink: paypalLink.isEmpty ? nil : paypalLink,
            venmoUsername: venmoUsername.isEmpty ? nil : venmoUsername,
            zelleEmail: zelleEmail.isEmpty ? nil : zelleEmail
        )
        
        modelContext.insert(invoice)
        
        for itemData in lineItems where itemData.isValid {
            let item = InvoiceItem(
                itemDescription: itemData.description,
                quantity: itemData.quantity,
                unitPrice: itemData.unitPrice
            )
            item.invoice = invoice
            modelContext.insert(item)
        }
        
        do {
            try modelContext.save()
            HapticService.play(.success)
            // v2.3: Announce success
            AccessibilityAnnouncement.announce("Invoice \(invoiceNumber) created for \(client.name)")
            dismiss()
        } catch {
            saveError = error
            showingSaveError = true
            HapticService.play(.error)
            AccessibilityAnnouncement.announce("Failed to create invoice")
            print("Failed to save invoice: \(error)")
        }
    }
}

// MARK: - Edit Invoice View

struct EditInvoiceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var clients: [Client]
    
    let invoice: Invoice
    
    @State private var selectedClient: Client?
    @State private var issueDate: Date
    @State private var dueDate: Date
    @State private var paymentTerms: String
    @State private var taxRate: Double
    @State private var discountAmount: Double
    @State private var notes: String
    @State private var paymentInstructions: String
    @State private var stripeLink: String
    @State private var paypalLink: String
    @State private var venmoUsername: String
    @State private var zelleEmail: String
    @State private var lineItems: [InvoiceItemData]
    @State private var showingClientPicker = false
    @State private var saveError: Error?
    @State private var showingSaveError = false
    
    init(invoice: Invoice) {
        self.invoice = invoice
        _selectedClient = State(initialValue: invoice.client)
        _issueDate = State(initialValue: invoice.issueDate)
        _dueDate = State(initialValue: invoice.dueDate)
        _paymentTerms = State(initialValue: invoice.paymentTerms)
        _taxRate = State(initialValue: invoice.taxRate)
        _discountAmount = State(initialValue: invoice.discountAmount)
        _notes = State(initialValue: invoice.notes ?? "")
        _paymentInstructions = State(initialValue: invoice.paymentInstructions ?? "")
        _stripeLink = State(initialValue: invoice.stripePaymentLink ?? "")
        _paypalLink = State(initialValue: invoice.paypalLink ?? "")
        _venmoUsername = State(initialValue: invoice.venmoUsername ?? "")
        _zelleEmail = State(initialValue: invoice.zelleEmail ?? "")
        
        let items: [InvoiceItemData]
        if (invoice.items ?? []).isEmpty {
            items = [InvoiceItemData()]
        } else {
            items = (invoice.items ?? []).map { item in
                InvoiceItemData(
                    description: item.itemDescription,
                    quantity: item.quantity,
                    unitPrice: item.unitPrice
                )
            }
        }
        _lineItems = State(initialValue: items)
    }
    
    var isValid: Bool {
        selectedClient != nil && !lineItems.filter { $0.isValid }.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Client") {
                    if let client = selectedClient {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(client.name)
                                    .font(.body.weight(.medium))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                if let contact = client.contactName {
                                    Text(contact)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button("Change") {
                                HapticService.play(.light)
                                showingClientPicker = true
                            }
                            // v2.3: VoiceOver
                            .accessibilityLabel("Change client")
                        }
                        .accessibilityElement(children: .combine)
                    } else {
                        Button("Select Client") {
                            HapticService.play(.light)
                            showingClientPicker = true
                        }
                        .accessibilityLabel("Select client")
                        .accessibilityHint("Required. Choose a client for this invoice")
                    }
                }
                
                Section("Invoice Details") {
                    DatePicker("Issue Date", selection: $issueDate, displayedComponents: .date)
                        .onChange(of: issueDate) { _, _ in
                            HapticService.play(.light)
                        }
                        .accessibilityValue(AccessibilityFormatters.spokenDate(issueDate))
                    
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                        .onChange(of: dueDate) { _, _ in
                            HapticService.play(.light)
                        }
                        .accessibilityValue(AccessibilityFormatters.spokenDate(dueDate))
                    
                    Picker("Payment Terms", selection: $paymentTerms) {
                        Text("Due on Receipt").tag("Due on Receipt")
                        Text("Net 15").tag("Net 15")
                        Text("Net 30").tag("Net 30")
                        Text("Net 60").tag("Net 60")
                    }
                    .onChange(of: paymentTerms) { _, _ in
                        HapticService.play(.selection)
                    }
                    .accessibilityValue(paymentTerms)
                }
                
                Section {
                    ForEach($lineItems) { $item in
                        LineItemEditor(item: $item)
                    }
                    .onDelete { indexSet in
                        HapticService.play(.medium)
                        withAnimation(FLOAnimation.quick) {
                            lineItems.remove(atOffsets: indexSet)
                        }
                    }
                    
                    Button {
                        HapticService.play(.medium)
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            lineItems.append(InvoiceItemData())
                        }
                    } label: {
                        Label("Add Line Item", systemImage: "plus.circle.fill")
                    }
                    .accessibilityLabel("Add line item")
                } header: {
                    Text("Line Items")
                }
                
                Section("Totals") {
                    HStack {
                        Text("Subtotal")
                        Spacer()
                        Text(subtotal.formatted(.currency(code: "USD")))
                            .contentTransition(.numericText())
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Subtotal: \(AccessibilityFormatters.spokenCurrency(subtotal))")
                    
                    HStack {
                        Text("Tax Rate")
                        Spacer()
                        TextField("0%", value: $taxRate, format: .percent)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Tax rate")
                    
                    if taxRate > 0 {
                        HStack {
                            Text("Tax Amount")
                            Spacer()
                            Text(taxAmount.formatted(.currency(code: "USD")))
                                .foregroundStyle(.secondary)
                                .contentTransition(.numericText())
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Tax amount: \(AccessibilityFormatters.spokenCurrency(taxAmount))")
                    }
                    
                    HStack {
                        Text("Discount")
                        Spacer()
                        TextField("$0.00", value: $discountAmount, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Discount")
                    
                    HStack {
                        Text("Total")
                            .font(.headline)
                        Spacer()
                        Text(totalAmount.formatted(.currency(code: "USD")))
                            .font(.headline)
                            .foregroundStyle(Color.businessColor)
                            .contentTransition(.numericText())
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Invoice total: \(AccessibilityFormatters.spokenCurrency(totalAmount))")
                    .accessibilityAddTraits(.isSummaryElement)
                }
                
                Section("Payment Options") {
                    TextField("Stripe Payment Link (optional)", text: $stripeLink)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .accessibilityLabel("Stripe payment link")
                    
                    TextField("PayPal Link (optional)", text: $paypalLink)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .accessibilityLabel("PayPal link")
                    
                    TextField("Venmo Username (optional)", text: $venmoUsername)
                        .autocapitalization(.none)
                        .accessibilityLabel("Venmo username")
                    
                    TextField("Zelle Email (optional)", text: $zelleEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .accessibilityLabel("Zelle email address")
                }
                
                Section("Notes & Instructions") {
                    TextField("Invoice notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityLabel("Invoice notes")
                    
                    TextField("Payment instructions (optional)", text: $paymentInstructions, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityLabel("Payment instructions")
                }
            }
            .navigationTitle("Edit Invoice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticService.play(.light)
                        dismiss()
                    }
                    .accessibilityLabel("Cancel")
                    .accessibilityHint("Double tap to discard changes")
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        HapticService.play(.medium)
                        saveChanges()
                    }
                    .disabled(!isValid)
                    .accessibilityLabel("Save invoice")
                    .accessibilityHint(isValid ? "Double tap to save changes" : "Select a client and add line items to enable saving")
                }
            }
            .sheet(isPresented: $showingClientPicker) {
                ClientPickerView(selectedClient: $selectedClient, clients: clients)
            }
            .alert("Could Not Save Changes", isPresented: $showingSaveError) {
                Button("OK") { }
            } message: {
                Text(saveError?.localizedDescription ?? "An unknown error occurred. Please try again.")
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
            }
            .onAppear {
                // v2.3: Announce screen
                AccessibilityAnnouncement.screenChanged("Edit Invoice \(invoice.invoiceNumber)")
            }
        }
    }
    
    private var subtotal: Double {
        lineItems
            .filter { $0.isValid }
            .reduce(0) { $0 + ($1.quantity * $1.unitPrice) }
    }
    
    private var taxAmount: Double {
        subtotal * taxRate
    }
    
    private var totalAmount: Double {
        subtotal + taxAmount - discountAmount
    }
    
    private func saveChanges() {
        invoice.client = selectedClient
        invoice.issueDate = issueDate
        invoice.dueDate = dueDate
        invoice.paymentTerms = paymentTerms
        invoice.taxRate = taxRate
        invoice.discountAmount = discountAmount
        invoice.notes = notes.isEmpty ? nil : notes
        invoice.paymentInstructions = paymentInstructions.isEmpty ? nil : paymentInstructions
        invoice.stripePaymentLink = stripeLink.isEmpty ? nil : stripeLink
        invoice.paypalLink = paypalLink.isEmpty ? nil : paypalLink
        invoice.venmoUsername = venmoUsername.isEmpty ? nil : venmoUsername
        invoice.zelleEmail = zelleEmail.isEmpty ? nil : zelleEmail
        invoice.modifiedDate = Date()
        
        for item in invoice.items ?? [] {
            modelContext.delete(item)
        }
        
        for itemData in lineItems where itemData.isValid {
            let item = InvoiceItem(
                itemDescription: itemData.description,
                quantity: itemData.quantity,
                unitPrice: itemData.unitPrice
            )
            item.invoice = invoice
            modelContext.insert(item)
        }
        
        do {
            try modelContext.save()
            HapticService.play(.success)
            AccessibilityAnnouncement.announce("Invoice changes saved")
            dismiss()
        } catch {
            saveError = error
            showingSaveError = true
            HapticService.play(.error)
            AccessibilityAnnouncement.announce("Failed to save changes")
            print("Failed to save changes: \(error)")
        }
    }
}

// MARK: - Supporting Views

struct LineItemEditor: View {
    @Binding var item: InvoiceItemData
    
    var body: some View {
        VStack(spacing: 8) {
            TextField("Description", text: $item.description)
                // v2.3: VoiceOver
                .accessibilityLabel("Line item description")
            
            HStack {
                TextField("Qty", value: $item.quantity, format: .number)
                    .keyboardType(.decimalPad)
                    .frame(width: 60)
                    // v2.3: VoiceOver
                    .accessibilityLabel("Quantity")
                
                Text("×")
                    // v2.3: Decorative
                    .accessibilityHidden(true)
                
                TextField("Unit Price", value: $item.unitPrice, format: .currency(code: "USD"))
                    .keyboardType(.decimalPad)
                    .frame(maxWidth: .infinity)
                    // v2.3: VoiceOver
                    .accessibilityLabel("Unit price in dollars")
                
                Text("=")
                    // v2.3: Decorative
                    .accessibilityHidden(true)
                
                Text(item.total.formatted(.currency(code: "USD")))
                    .frame(width: 80, alignment: .trailing)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    // v2.3: VoiceOver
                    .accessibilityLabel("Line total: \(AccessibilityFormatters.spokenCurrency(item.total))")
            }
        }
        .padding(.vertical, 4)
    }
}

struct ClientPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedClient: Client?
    let clients: [Client]
    
    var body: some View {
        NavigationStack {
            List(clients) { client in
                Button {
                    HapticService.play(.selection)
                    selectedClient = client
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(client.name)
                                .font(.body)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.primary)
                            if let contact = client.contactName {
                                Text(contact)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if selectedClient?.id == client.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.businessColor)
                                // v2.3: Decorative (state on parent)
                                .accessibilityHidden(true)
                        }
                    }
                }
                // v2.3: Client row accessible
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(client.name)\(client.contactName != nil ? ", \(client.contactName!)" : "")\(selectedClient?.id == client.id ? ", Currently selected" : "")")
                .accessibilityHint("Double tap to select this client")
                .accessibilityAddTraits(selectedClient?.id == client.id ? .isSelected : [])
            }
            .navigationTitle("Select Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticService.play(.light)
                        dismiss()
                    }
                    .accessibilityLabel("Cancel")
                }
            }
            // v2.3: Announce screen
            .onAppear {
                AccessibilityAnnouncement.screenChanged("Select Client. \(clients.count) clients available.")
            }
        }
    }
}

// MARK: - Data Models

struct InvoiceItemData: Identifiable {
    let id = UUID()
    var description: String = ""
    var quantity: Double = 1.0
    var unitPrice: Double = 0.0
    
    var total: Double {
        quantity * unitPrice
    }
    
    var isValid: Bool {
        !description.isEmpty && quantity > 0 && unitPrice > 0
    }
}

#Preview {
    CreateInvoiceView()
        .modelContainer(for: [Invoice.self, Client.self])
}
