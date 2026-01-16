//  CreateInvoiceView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.1 - Enhanced haptics and micro-animations
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v2.1:
//  ✅ Haptic feedback on client selection
//  ✅ Haptic on add/delete line items
//  ✅ Haptic on create/save
//  ✅ Form section animations
//  ✅ Total value animation
//  ✅ Line item animations
//  ✅ Success/error haptics
//
//  PREVIOUS (v2.0): Fixed hardcoded colors to use Color.businessTeal

import SwiftUI
import SwiftData

struct CreateInvoiceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
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
    
    // Haptic Generators
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    var isValid: Bool {
        selectedClient != nil && !lineItems.filter { $0.isValid }.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Client section
                Section("Client") {
                    if let client = selectedClient {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(client.name)
                                    .font(.body.weight(.medium))
                                if let contact = client.contactName {
                                    Text(contact)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button("Change") {
                                impactLight.impactOccurred()
                                showingClientPicker = true
                            }
                        }
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        Button("Select Client") {
                            impactLight.impactOccurred()
                            showingClientPicker = true
                        }
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedClient != nil)
                
                // Invoice details
                Section("Invoice Details") {
                    DatePicker("Issue Date", selection: $issueDate, displayedComponents: .date)
                        .onChange(of: issueDate) { _, _ in
                            impactLight.impactOccurred()
                        }
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                        .onChange(of: dueDate) { _, _ in
                            impactLight.impactOccurred()
                        }
                    
                    Picker("Payment Terms", selection: $paymentTerms) {
                        Text("Due on Receipt").tag("Due on Receipt")
                        Text("Net 15").tag("Net 15")
                        Text("Net 30").tag("Net 30")
                        Text("Net 60").tag("Net 60")
                    }
                    .onChange(of: paymentTerms) { _, _ in
                        selectionFeedback.selectionChanged()
                    }
                }
                
                // Line items
                Section {
                    ForEach($lineItems) { $item in
                        LineItemEditor(item: $item)
                    }
                    .onDelete { indexSet in
                        impactMedium.impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            lineItems.remove(atOffsets: indexSet)
                        }
                    }
                    
                    Button {
                        impactMedium.impactOccurred()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            lineItems.append(InvoiceItemData())
                        }
                    } label: {
                        Label("Add Line Item", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Line Items")
                } footer: {
                    Text("Tap to edit quantities, prices, and descriptions")
                }
                
                // Totals
                Section("Totals") {
                    HStack {
                        Text("Subtotal")
                        Spacer()
                        Text(subtotal.formatted(.currency(code: "USD")))
                            .contentTransition(.numericText())
                    }
                    
                    HStack {
                        Text("Tax Rate")
                        Spacer()
                        TextField("0%", value: $taxRate, format: .percent)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    if taxRate > 0 {
                        HStack {
                            Text("Tax Amount")
                            Spacer()
                            Text(taxAmount.formatted(.currency(code: "USD")))
                                .foregroundStyle(.secondary)
                                .contentTransition(.numericText())
                        }
                        .transition(.opacity)
                    }
                    
                    HStack {
                        Text("Discount")
                        Spacer()
                        TextField("$0.00", value: $discountAmount, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Text("Total")
                            .font(.headline)
                        Spacer()
                        Text(totalAmount.formatted(.currency(code: "USD")))
                            .font(.headline)
                            .foregroundStyle(Color.businessColor)
                            .contentTransition(.numericText())
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: taxRate > 0)
                
                // Payment options
                Section("Payment Options") {
                    TextField("Stripe Payment Link (optional)", text: $stripeLink)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                    
                    TextField("PayPal Link (optional)", text: $paypalLink)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                    
                    TextField("Venmo Username (optional)", text: $venmoUsername)
                        .autocapitalization(.none)
                    
                    TextField("Zelle Email (optional)", text: $zelleEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                
                // Notes
                Section("Notes & Instructions") {
                    TextField("Invoice notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                    
                    TextField("Payment instructions (optional)", text: $paymentInstructions, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("New Invoice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        impactLight.impactOccurred()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        impactMedium.impactOccurred()
                        createInvoice()
                    }
                    .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showingClientPicker) {
                ClientPickerView(selectedClient: $selectedClient, clients: clients)
            }
            .alert("Could Not Save Invoice", isPresented: $showingSaveError) {
                Button("OK") { }
            } message: {
                Text(saveError?.localizedDescription ?? "An unknown error occurred. Please try again.")
            }
            .onAppear {
                prepareHaptics()
            }
            .onChange(of: selectedClient) { oldValue, newValue in
                if newValue != nil {
                    notificationFeedback.notificationOccurred(.success)
                }
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
            notificationFeedback.notificationOccurred(.success)
            dismiss()
        } catch {
            saveError = error
            showingSaveError = true
            notificationFeedback.notificationOccurred(.error)
            print("❌ Failed to save invoice: \(error)")
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
    
    // Haptic Generators
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
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
        if invoice.items.isEmpty {
            items = [InvoiceItemData()]
        } else {
            items = invoice.items.map { item in
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
                                if let contact = client.contactName {
                                    Text(contact)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button("Change") {
                                impactLight.impactOccurred()
                                showingClientPicker = true
                            }
                        }
                    } else {
                        Button("Select Client") {
                            impactLight.impactOccurred()
                            showingClientPicker = true
                        }
                    }
                }
                
                Section("Invoice Details") {
                    DatePicker("Issue Date", selection: $issueDate, displayedComponents: .date)
                        .onChange(of: issueDate) { _, _ in
                            impactLight.impactOccurred()
                        }
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                        .onChange(of: dueDate) { _, _ in
                            impactLight.impactOccurred()
                        }
                    
                    Picker("Payment Terms", selection: $paymentTerms) {
                        Text("Due on Receipt").tag("Due on Receipt")
                        Text("Net 15").tag("Net 15")
                        Text("Net 30").tag("Net 30")
                        Text("Net 60").tag("Net 60")
                    }
                    .onChange(of: paymentTerms) { _, _ in
                        selectionFeedback.selectionChanged()
                    }
                }
                
                Section {
                    ForEach($lineItems) { $item in
                        LineItemEditor(item: $item)
                    }
                    .onDelete { indexSet in
                        impactMedium.impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            lineItems.remove(atOffsets: indexSet)
                        }
                    }
                    
                    Button {
                        impactMedium.impactOccurred()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            lineItems.append(InvoiceItemData())
                        }
                    } label: {
                        Label("Add Line Item", systemImage: "plus.circle.fill")
                    }
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
                    
                    HStack {
                        Text("Tax Rate")
                        Spacer()
                        TextField("0%", value: $taxRate, format: .percent)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    if taxRate > 0 {
                        HStack {
                            Text("Tax Amount")
                            Spacer()
                            Text(taxAmount.formatted(.currency(code: "USD")))
                                .foregroundStyle(.secondary)
                                .contentTransition(.numericText())
                        }
                    }
                    
                    HStack {
                        Text("Discount")
                        Spacer()
                        TextField("$0.00", value: $discountAmount, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Text("Total")
                            .font(.headline)
                        Spacer()
                        Text(totalAmount.formatted(.currency(code: "USD")))
                            .font(.headline)
                            .foregroundStyle(Color.businessColor)
                            .contentTransition(.numericText())
                    }
                }
                
                Section("Payment Options") {
                    TextField("Stripe Payment Link (optional)", text: $stripeLink)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                    
                    TextField("PayPal Link (optional)", text: $paypalLink)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                    
                    TextField("Venmo Username (optional)", text: $venmoUsername)
                        .autocapitalization(.none)
                    
                    TextField("Zelle Email (optional)", text: $zelleEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                
                Section("Notes & Instructions") {
                    TextField("Invoice notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                    
                    TextField("Payment instructions (optional)", text: $paymentInstructions, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Invoice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        impactLight.impactOccurred()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        impactMedium.impactOccurred()
                        saveChanges()
                    }
                    .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showingClientPicker) {
                ClientPickerView(selectedClient: $selectedClient, clients: clients)
            }
            .alert("Could Not Save Changes", isPresented: $showingSaveError) {
                Button("OK") { }
            } message: {
                Text(saveError?.localizedDescription ?? "An unknown error occurred. Please try again.")
            }
            .onAppear {
                prepareHaptics()
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
        
        for item in invoice.items {
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
            notificationFeedback.notificationOccurred(.success)
            dismiss()
        } catch {
            saveError = error
            showingSaveError = true
            notificationFeedback.notificationOccurred(.error)
            print("❌ Failed to save changes: \(error)")
        }
    }
}

// MARK: - Supporting Views

struct LineItemEditor: View {
    @Binding var item: InvoiceItemData
    
    var body: some View {
        VStack(spacing: 8) {
            TextField("Description", text: $item.description)
            
            HStack {
                TextField("Qty", value: $item.quantity, format: .number)
                    .keyboardType(.decimalPad)
                    .frame(width: 60)
                
                Text("×")
                
                TextField("Unit Price", value: $item.unitPrice, format: .currency(code: "USD"))
                    .keyboardType(.decimalPad)
                    .frame(maxWidth: .infinity)
                
                Text("=")
                
                Text(item.total.formatted(.currency(code: "USD")))
                    .frame(width: 80, alignment: .trailing)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
        }
        .padding(.vertical, 4)
    }
}

struct ClientPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedClient: Client?
    let clients: [Client]
    
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    
    var body: some View {
        NavigationStack {
            List(clients) { client in
                Button {
                    selectionFeedback.selectionChanged()
                    selectedClient = client
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(client.name)
                                .font(.body)
                                .foregroundStyle(.primary)
                            if let contact = client.contactName {
                                Text(contact)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if selectedClient?.id == client.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.businessColor)
                        }
                    }
                }
            }
            .navigationTitle("Select Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        impactLight.impactOccurred()
                        dismiss()
                    }
                }
            }
            .onAppear {
                impactLight.prepare()
                selectionFeedback.prepare()
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
