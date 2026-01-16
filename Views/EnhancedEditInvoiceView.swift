//  EnhancedEditInvoiceView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Full invoice editing with haptics and animations
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  FEATURES:
//  ✅ Edit all invoice fields (client, dates, line items, etc.)
//  ✅ Pre-populated from existing invoice
//  ✅ Haptic feedback on all interactions
//  ✅ Animated form sections
//  ✅ Line item management (add/edit/delete)
//  ✅ Real-time total calculations
//  ✅ Payment link editing
//  ✅ Status change capability
//  ✅ Validation before save
//

import SwiftUI
import SwiftData

struct EnhancedEditInvoiceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var clients: [Client]
    
    let invoice: Invoice
    
    // MARK: - Form State
    @State private var selectedClient: Client?
    @State private var invoiceNumber: String = ""
    @State private var issueDate = Date()
    @State private var dueDate = Date()
    @State private var paymentTerms = "Net 30"
    @State private var status: InvoiceStatus = .draft
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
    @State private var lineItems: [EditableLineItem] = []
    
    // UI State
    @State private var showingClientPicker = false
    @State private var saveError: Error?
    @State private var showingSaveError = false
    @State private var viewAppeared = false
    @State private var showingDeleteLineItemAlert = false
    @State private var lineItemToDelete: EditableLineItem?
    
    // Haptic Generators
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    // MARK: - Validation
    
    var isValid: Bool {
        selectedClient != nil && !lineItems.filter { $0.isValid }.isEmpty
    }
    
    var hasChanges: Bool {
        // Check if any field has changed from original
        selectedClient?.id != invoice.client?.id ||
        issueDate != invoice.issueDate ||
        dueDate != invoice.dueDate ||
        paymentTerms != invoice.paymentTerms ||
        status != invoice.status ||
        taxRate != invoice.taxRate ||
        discountAmount != invoice.discountAmount ||
        notes != (invoice.notes ?? "") ||
        paymentInstructions != (invoice.paymentInstructions ?? "") ||
        stripeLink != (invoice.stripePaymentLink ?? "") ||
        paypalLink != (invoice.paypalLink ?? "") ||
        venmoUsername != (invoice.venmoUsername ?? "") ||
        zelleEmail != (invoice.zelleEmail ?? "") ||
        lineItemsChanged
    }
    
    private var lineItemsChanged: Bool {
        let validItems = lineItems.filter { $0.isValid }
        if validItems.count != invoice.items.count { return true }
        
        for (index, item) in validItems.enumerated() {
            guard index < invoice.items.count else { return true }
            let original = invoice.items[index]
            if item.description != original.itemDescription ||
               item.quantity != original.quantity ||
               item.unitPrice != original.unitPrice {
                return true
            }
        }
        return false
    }
    
    // MARK: - Computed Properties
    
    var subtotal: Double {
        lineItems
            .filter { $0.isValid }
            .reduce(0) { $0 + ($1.quantity * $1.unitPrice) }
    }
    
    var taxAmount: Double {
        subtotal * taxRate
    }
    
    var totalAmount: Double {
        subtotal + taxAmount - discountAmount
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // Invoice Number (read-only display)
                Section {
                    HStack {
                        Text("Invoice Number")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(invoiceNumber)
                            .fontWeight(.medium)
                    }
                }
                .opacity(viewAppeared ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: viewAppeared)
                
                // Client section
                Section("Client") {
                    if let client = selectedClient {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(client.name)
                                    .font(.body.weight(.medium))
                                if let contact = client.contactName {
                                    Text(contact)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let email = client.email {
                                    Text(email)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button("Change") {
                                impactLight.impactOccurred()
                                showingClientPicker = true
                            }
                            .foregroundStyle(Color.businessColor)
                        }
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        Button {
                            impactLight.impactOccurred()
                            showingClientPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                    .foregroundStyle(Color.businessColor)
                                Text("Select Client")
                                    .foregroundStyle(Color.businessColor)
                            }
                        }
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedClient != nil)
                .opacity(viewAppeared ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: viewAppeared)
                
                // Status section
                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(InvoiceStatus.allCases, id: \.self) { status in
                            HStack {
                                Circle()
                                    .fill(statusColor(for: status))
                                    .frame(width: 10, height: 10)
                                Text(statusLabel(for: status))
                            }
                            .tag(status)
                        }
                    }
                    .onChange(of: status) { _, _ in
                        selectionFeedback.selectionChanged()
                    }
                }
                .opacity(viewAppeared ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: viewAppeared)
                
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
                        Text("Custom").tag("Custom")
                    }
                    .onChange(of: paymentTerms) { oldValue, newValue in
                        selectionFeedback.selectionChanged()
                        // Auto-update due date based on payment terms
                        if newValue != oldValue {
                            updateDueDateFromTerms(newValue)
                        }
                    }
                }
                .opacity(viewAppeared ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: viewAppeared)
                
                // Line items
                Section {
                    ForEach($lineItems) { $item in
                        EditableLineItemRow(item: $item)
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity),
                                removal: .scale.combined(with: .opacity)
                            ))
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
                            lineItems.append(EditableLineItem())
                        }
                    } label: {
                        Label("Add Line Item", systemImage: "plus.circle.fill")
                            .foregroundStyle(Color.businessColor)
                    }
                } header: {
                    Text("Line Items")
                } footer: {
                    if lineItems.filter({ $0.isValid }).isEmpty {
                        Text("Add at least one line item with description, quantity, and price")
                            .foregroundStyle(.red)
                    } else {
                        Text("Swipe left to delete items")
                    }
                }
                .opacity(viewAppeared ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.25), value: viewAppeared)
                
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
                .opacity(viewAppeared ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3), value: viewAppeared)
                
                // Payment options
                Section("Payment Options") {
                    TextField("Stripe Payment Link", text: $stripeLink)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                    
                    TextField("PayPal Link", text: $paypalLink)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                    
                    TextField("Venmo Username", text: $venmoUsername)
                        .autocapitalization(.none)
                    
                    TextField("Zelle Email", text: $zelleEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                .opacity(viewAppeared ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.35), value: viewAppeared)
                
                // Notes
                Section("Notes & Instructions") {
                    TextField("Invoice notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                    
                    TextField("Payment instructions", text: $paymentInstructions, axis: .vertical)
                        .lineLimit(3...6)
                }
                .opacity(viewAppeared ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.4), value: viewAppeared)
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
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingClientPicker) {
                EditInvoiceClientPicker(selectedClient: $selectedClient, clients: clients)
            }
            .alert("Could Not Save Changes", isPresented: $showingSaveError) {
                Button("OK") { }
            } message: {
                Text(saveError?.localizedDescription ?? "An unknown error occurred. Please try again.")
            }
            .onAppear {
                prepareHaptics()
                loadInvoiceData()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        viewAppeared = true
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func prepareHaptics() {
        selectionFeedback.prepare()
        impactLight.prepare()
        impactMedium.prepare()
        notificationFeedback.prepare()
    }
    
    private func loadInvoiceData() {
        // Load all data from the invoice
        selectedClient = invoice.client
        invoiceNumber = invoice.invoiceNumber
        issueDate = invoice.issueDate
        dueDate = invoice.dueDate
        paymentTerms = invoice.paymentTerms
        status = invoice.status
        taxRate = invoice.taxRate
        discountAmount = invoice.discountAmount
        notes = invoice.notes ?? ""
        paymentInstructions = invoice.paymentInstructions ?? ""
        stripeLink = invoice.stripePaymentLink ?? ""
        paypalLink = invoice.paypalLink ?? ""
        venmoUsername = invoice.venmoUsername ?? ""
        zelleEmail = invoice.zelleEmail ?? ""
        
        // Load line items
        lineItems = invoice.items.map { item in
            EditableLineItem(
                id: item.id,
                description: item.itemDescription,
                quantity: item.quantity,
                unitPrice: item.unitPrice
            )
        }
        
        // Ensure at least one line item row
        if lineItems.isEmpty {
            lineItems.append(EditableLineItem())
        }
    }
    
    private func updateDueDateFromTerms(_ terms: String) {
        switch terms {
        case "Due on Receipt":
            dueDate = issueDate
        case "Net 15":
            dueDate = issueDate.addingTimeInterval(15 * 86400)
        case "Net 30":
            dueDate = issueDate.addingTimeInterval(30 * 86400)
        case "Net 60":
            dueDate = issueDate.addingTimeInterval(60 * 86400)
        default:
            break // Custom - don't change
        }
    }
    
    private func statusColor(for status: InvoiceStatus) -> Color {
        switch status {
        case .draft: return .gray
        case .sent: return .blue
        case .viewed: return .purple
        case .partiallyPaid: return .orange
        case .paid: return .green
        case .overdue: return .red
        case .cancelled: return .gray
        }
    }
    
    private func statusLabel(for status: InvoiceStatus) -> String {
        switch status {
        case .draft: return "Draft"
        case .sent: return "Sent"
        case .viewed: return "Viewed"
        case .partiallyPaid: return "Partially Paid"
        case .paid: return "Paid"
        case .overdue: return "Overdue"
        case .cancelled: return "Cancelled"
        }
    }
    
    private func saveChanges() {
        // Update invoice properties
        invoice.client = selectedClient
        invoice.issueDate = issueDate
        invoice.dueDate = dueDate
        invoice.paymentTerms = paymentTerms
        invoice.status = status
        invoice.taxRate = taxRate
        invoice.discountAmount = discountAmount
        invoice.notes = notes.isEmpty ? nil : notes
        invoice.paymentInstructions = paymentInstructions.isEmpty ? nil : paymentInstructions
        invoice.stripePaymentLink = stripeLink.isEmpty ? nil : stripeLink
        invoice.paypalLink = paypalLink.isEmpty ? nil : paypalLink
        invoice.venmoUsername = venmoUsername.isEmpty ? nil : venmoUsername
        invoice.zelleEmail = zelleEmail.isEmpty ? nil : zelleEmail
        invoice.modifiedDate = Date()
        
        // Update line items
        // First, remove all existing items
        for item in invoice.items {
            modelContext.delete(item)
        }
        
        // Then add updated items
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
            print("❌ Failed to save invoice changes: \(error)")
        }
    }
}

// MARK: - Editable Line Item Model

struct EditableLineItem: Identifiable {
    var id = UUID()
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

// MARK: - Editable Line Item Row

struct EditableLineItemRow: View {
    @Binding var item: EditableLineItem
    
    var body: some View {
        VStack(spacing: 8) {
            TextField("Description", text: $item.description)
                .font(.body)
            
            HStack {
                HStack(spacing: 4) {
                    Text("Qty:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("1", value: $item.quantity, format: .number)
                        .keyboardType(.decimalPad)
                        .frame(width: 50)
                        .textFieldStyle(.roundedBorder)
                }
                
                Text("×")
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 4) {
                    Text("Price:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("$0.00", value: $item.unitPrice, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                        .frame(width: 90)
                        .textFieldStyle(.roundedBorder)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Total")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(item.total.formatted(.currency(code: "USD")))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.businessColor)
                        .contentTransition(.numericText())
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Client Picker for Edit

struct EditInvoiceClientPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedClient: Client?
    let clients: [Client]
    
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    
    var body: some View {
        NavigationStack {
            Group {
                if clients.isEmpty {
                    ContentUnavailableView {
                        Label("No Clients", systemImage: "person.crop.circle.badge.questionmark")
                    } description: {
                        Text("Add clients in the Clients section before creating invoices.")
                    }
                } else {
                    List(clients) { client in
                        Button {
                            selectionFeedback.selectionChanged()
                            selectedClient = client
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(client.name)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    if let contact = client.contactName {
                                        Text(contact)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let email = client.email {
                                        Text(email)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if selectedClient?.id == client.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.businessColor)
                                        .font(.title3)
                                }
                            }
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

// MARK: - Preview

#Preview {
    EditInvoiceView(invoice: Invoice(
        invoiceNumber: "INV-2024-001",
        client: nil,
        issueDate: Date(),
        dueDate: Date().addingTimeInterval(30 * 86400),
        status: .draft,
        paymentTerms: "Net 30",
        taxRate: 0.0825,
        discountAmount: 0
    ))
    .modelContainer(for: [Invoice.self, Client.self, InvoiceItem.self])
}
