//  EnhancedEditInvoiceView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.2 - Dynamic Type verification: lineLimit + minimumScaleFactor on all text
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.2 - Dynamic Type Verification:
//  ✅ FIXED: "Invoice Number" label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Invoice number value missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Client name text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Client contact and email text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Change" button text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Select Client" button text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Status picker labels missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Payment terms picker labels missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Line items footer text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Totals labels (Subtotal, Tax Rate, Tax Amount, Discount, Total) missing lineLimit + minimumScaleFactor
//  ✅ FIXED: EditableLineItemRow quantity and price labels missing lineLimit + minimumScaleFactor
//  ✅ FIXED: EditableLineItemRow "Total" label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Client picker name, contact, email text missing lineLimit + minimumScaleFactor
//
//  CHANGES v1.1:
//  ✅ ADDED: Invoice number row accessible
//  ✅ ADDED: Client section accessible (name + contact + email combined)
//  ✅ ADDED: Status picker with spoken status and color dots hidden
//  ✅ ADDED: Invoice details date pickers with spoken dates
//  ✅ ADDED: Payment terms picker accessible
//  ✅ ADDED: EditableLineItemRow accessible (fields labeled, total spoken)
//  ✅ ADDED: Add Line Item button labeled with hint
//  ✅ ADDED: Line item validation footer accessible
//  ✅ ADDED: Totals section rows accessible with spoken currency
//  ✅ ADDED: Total row marked as isSummaryElement
//  ✅ ADDED: Payment option fields labeled
//  ✅ ADDED: Notes fields labeled
//  ✅ ADDED: Cancel/Save toolbar buttons with dynamic hints
//  ✅ ADDED: EditInvoiceClientPicker rows accessible with selection state
//  ✅ ADDED: Screen change announcement on appear
//  ✅ ADDED: Save success/failure announced
//  ✅ ADDED: Decorative icons hidden
//
//  CHANGES v1.0:
//  - Full invoice editing with haptics and animations
//

import SwiftUI
import FLODesignSystem
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
    
    // MARK: - Validation
    
    var isValid: Bool {
        selectedClient != nil && !lineItems.filter { $0.isValid }.isEmpty
    }
    
    var hasChanges: Bool {
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
        let invoiceItems = invoice.items ?? []
        if validItems.count != invoiceItems.count { return true }

        for (index, item) in validItems.enumerated() {
            guard index < invoiceItems.count else { return true }
            let original = invoiceItems[index]
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
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(invoiceNumber)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    // v1.1: VoiceOver
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Invoice number: \(invoiceNumber)")
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)
                
                // Client section
                Section("Client") {
                    if let client = selectedClient {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
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
                                if let email = client.email {
                                    Text(email)
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
                            .foregroundStyle(Color.businessColor)
                            // v1.1: VoiceOver
                            .accessibilityLabel("Change client")
                        }
                        // v1.1: Combined label
                        .accessibilityElement(children: .combine)
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        Button {
                            HapticService.play(.light)
                            showingClientPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                    .foregroundStyle(Color.businessColor)
                                    // v1.1: Decorative
                                    .accessibilityHidden(true)
                                Text("Select Client")
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                    .foregroundStyle(Color.businessColor)
                            }
                        }
                        // v1.1: VoiceOver
                        .accessibilityLabel("Select client")
                        .accessibilityHint("Required. Choose a client for this invoice")
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedClient != nil)
                .opacity(viewAppeared ? 1 : 0.001)
                .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
                
                // Status section
                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(InvoiceStatus.allCases, id: \.self) { status in
                            HStack {
                                Circle()
                                    .fill(statusColor(for: status))
                                    .frame(width: 10, height: 10)
                                Text(statusLabel(for: status))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .tag(status)
                        }
                    }
                    .onChange(of: status) { _, _ in
                        HapticService.play(.selection)
                    }
                    // v1.1: VoiceOver
                    .accessibilityLabel("Invoice status")
                    .accessibilityValue(statusLabel(for: status))
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)
                
                // Invoice details
                Section("Invoice Details") {
                    DatePicker("Issue Date", selection: $issueDate, displayedComponents: .date)
                        .onChange(of: issueDate) { _, _ in
                            HapticService.play(.light)
                        }
                        // v1.1: VoiceOver
                        .accessibilityValue(AccessibilityFormatters.spokenDate(issueDate))
                    
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                        .onChange(of: dueDate) { _, _ in
                            HapticService.play(.light)
                        }
                        // v1.1: VoiceOver
                        .accessibilityValue(AccessibilityFormatters.spokenDate(dueDate))
                    
                    Picker("Payment Terms", selection: $paymentTerms) {
                        Text("Due on Receipt")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .tag("Due on Receipt")
                        Text("Net 15")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .tag("Net 15")
                        Text("Net 30")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .tag("Net 30")
                        Text("Net 60")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .tag("Net 60")
                        Text("Custom")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .tag("Custom")
                    }
                    .onChange(of: paymentTerms) { oldValue, newValue in
                        HapticService.play(.selection)
                        if newValue != oldValue {
                            updateDueDateFromTerms(newValue)
                        }
                    }
                    // v1.1: VoiceOver
                    .accessibilityValue(paymentTerms)
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)
                
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
                        HapticService.play(.medium)
                        withAnimation(FLOAnimation.quick) {
                            lineItems.remove(atOffsets: indexSet)
                        }
                        // v1.1: Announce
                        AccessibilityAnnouncement.announce("Line item removed. \(lineItems.count) items remaining.")
                    }
                    
                    Button {
                        HapticService.play(.medium)
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            lineItems.append(EditableLineItem())
                        }
                        AccessibilityAnnouncement.announce("Line item added")
                    } label: {
                        Label("Add Line Item", systemImage: "plus.circle.fill")
                            .foregroundStyle(Color.businessColor)
                    }
                    // v1.1: VoiceOver
                    .accessibilityLabel("Add line item")
                    .accessibilityHint("Double tap to add a new line item")
                } header: {
                    Text("Line Items")
                } footer: {
                    if lineItems.filter({ $0.isValid }).isEmpty {
                        Text("Add at least one line item with description, quantity, and price")
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.red)
                    } else {
                        Text("Swipe left to delete items")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .animation(FLOAnimation.standard.delay(0.25), value: viewAppeared)
                
                // Totals
                Section("Totals") {
                    HStack {
                        Text("Subtotal")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer()
                        Text(subtotal.formatted(.currency(code: "USD")))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .contentTransition(.numericText())
                    }
                    // v1.1: VoiceOver
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Subtotal: \(AccessibilityFormatters.spokenCurrency(subtotal))")
                    
                    HStack {
                        Text("Tax Rate")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer()
                        TextField("0%", value: $taxRate, format: .percent)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Tax rate")
                    .accessibilityValue(taxRate > 0 ? "\(Int(taxRate * 100)) percent" : "0 percent")
                    
                    if taxRate > 0 {
                        HStack {
                            Text("Tax Amount")
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Spacer()
                            Text(taxAmount.formatted(.currency(code: "USD")))
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .foregroundStyle(.secondary)
                                .contentTransition(.numericText())
                        }
                        .transition(.opacity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Tax amount: \(AccessibilityFormatters.spokenCurrency(taxAmount))")
                    }
                    
                    HStack {
                        Text("Discount")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer()
                        TextField("$0.00", value: $discountAmount, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Discount")
                    .accessibilityValue(discountAmount > 0 ? AccessibilityFormatters.spokenCurrency(discountAmount) : "none")
                    
                    HStack {
                        Text("Total")
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer()
                        Text(totalAmount.formatted(.currency(code: "USD")))
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .foregroundStyle(Color.businessColor)
                            .contentTransition(.numericText())
                    }
                    // v1.1: VoiceOver
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Invoice total: \(AccessibilityFormatters.spokenCurrency(totalAmount))")
                    .accessibilityAddTraits(.isSummaryElement)
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: taxRate > 0)
                .opacity(viewAppeared ? 1 : 0.001)
                .animation(FLOAnimation.standard.delay(0.3), value: viewAppeared)
                
                // Payment options
                Section("Payment Options") {
                    TextField("Stripe Payment Link", text: $stripeLink)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        // v1.1: VoiceOver
                        .accessibilityLabel("Stripe payment link")
                    
                    TextField("PayPal Link", text: $paypalLink)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .accessibilityLabel("PayPal link")
                    
                    TextField("Venmo Username", text: $venmoUsername)
                        .autocapitalization(.none)
                        .accessibilityLabel("Venmo username")
                    
                    TextField("Zelle Email", text: $zelleEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .accessibilityLabel("Zelle email address")
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .animation(FLOAnimation.standard.delay(0.35), value: viewAppeared)
                
                // Notes
                Section("Notes & Instructions") {
                    TextField("Invoice notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        // v1.1: VoiceOver
                        .accessibilityLabel("Invoice notes")
                    
                    TextField("Payment instructions", text: $paymentInstructions, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityLabel("Payment instructions")
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .animation(FLOAnimation.standard.delay(0.4), value: viewAppeared)
            }
            .navigationTitle("Edit Invoice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticService.play(.light)
                        dismiss()
                    }
                    // v1.1: VoiceOver
                    .accessibilityLabel("Cancel")
                    .accessibilityHint("Double tap to discard changes")
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        HapticService.play(.medium)
                        saveChanges()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                    // v1.1: VoiceOver
                    .accessibilityLabel("Save invoice")
                    .accessibilityHint(isValid ? "Double tap to save your changes" : "Select a client and add line items to enable saving")
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
                loadInvoiceData()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        viewAppeared = true
                    }
                }
                // v1.1: Announce screen
                AccessibilityAnnouncement.screenChanged("Edit Invoice \(invoice.invoiceNumber)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadInvoiceData() {
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
        
        lineItems = (invoice.items ?? []).map { item in
            EditableLineItem(
                id: item.id,
                description: item.itemDescription,
                quantity: item.quantity,
                unitPrice: item.unitPrice
            )
        }
        
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
            break
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
            // v1.1: Announce save
            AccessibilityAnnouncement.announce("Invoice \(invoiceNumber) saved")
            dismiss()
        } catch {
            saveError = error
            showingSaveError = true
            HapticService.play(.error)
            AccessibilityAnnouncement.announce("Failed to save invoice changes")
            print("Failed to save invoice changes: \(error)")
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
                // v1.1: VoiceOver
                .accessibilityLabel("Line item description")
            
            HStack {
                HStack(spacing: 4) {
                    Text("Qty:")
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(.secondary)
                        // v1.1: Decorative (field label handles it)
                        .accessibilityHidden(true)
                    TextField("1", value: $item.quantity, format: .number)
                        .keyboardType(.decimalPad)
                        .frame(width: 50)
                        .textFieldStyle(.roundedBorder)
                        // v1.1: VoiceOver
                        .accessibilityLabel("Quantity")
                }
                
                Text("×")
                    .foregroundStyle(.secondary)
                    // v1.1: Decorative
                    .accessibilityHidden(true)
                
                HStack(spacing: 4) {
                    Text("Price:")
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    TextField("$0.00", value: $item.unitPrice, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                        .frame(width: 90)
                        .textFieldStyle(.roundedBorder)
                        // v1.1: VoiceOver
                        .accessibilityLabel("Unit price in dollars")
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Total")
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text(item.total.formatted(.currency(code: "USD")))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(Color.businessColor)
                        .contentTransition(.numericText())
                        // v1.1: VoiceOver
                        .accessibilityLabel("Line total: \(AccessibilityFormatters.spokenCurrency(item.total))")
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
                            HapticService.play(.selection)
                            selectedClient = client
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
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
                                    if let email = client.email {
                                        Text(email)
                                            .font(.caption)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if selectedClient?.id == client.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.businessColor)
                                        .font(.title3)
                                        // v1.1: Decorative
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                        // v1.1: Client row accessible
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(clientRowLabel(client))
                        .accessibilityHint("Double tap to select this client")
                        .accessibilityAddTraits(selectedClient?.id == client.id ? .isSelected : [])
                    }
                }
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
            // v1.1: Announce screen
            .onAppear {
                AccessibilityAnnouncement.screenChanged("Select Client. \(clients.count) clients available.")
            }
        }
    }
    
    // v1.1: Build client label
    private func clientRowLabel(_ client: Client) -> String {
        var parts = [client.name]
        if let contact = client.contactName { parts.append(contact) }
        if let email = client.email { parts.append(email) }
        if selectedClient?.id == client.id { parts.append("Currently selected") }
        return parts.joined(separator: ", ")
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
