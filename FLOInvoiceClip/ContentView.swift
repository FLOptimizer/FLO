//  QuickInvoiceView.swift
//  FLO Invoice Clip
//
//  Version 1.0 - Quick Invoice Generator
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE:
//  Streamlined invoice creation focused on speed. Allows users to create
//  an invoice with minimal input and share as PDF immediately.
//
//  FEATURES v1.0:
//  ✅ Minimal form: client name, line items, due date
//  ✅ Dynamic line item add/remove
//  ✅ Live total calculation
//  ✅ PDF generation and sharing via ShareLink
//  ✅ Full app download prompt
//  ✅ VoiceOver accessibility support
//  ✅ Dynamic Type support

import SwiftUI
import FLODesignSystem
import SwiftData

struct QuickInvoiceView: View {
    @Environment(\.modelContext) private var context

    // MARK: - Form State

    @State private var clientName = ""
    @State private var clientEmail = ""
    @State private var lineItems: [QuickLineItem] = [QuickLineItem()]
    @State private var taxRate: Double = 0.0
    @State private var paymentTermsDays = 30
    @State private var notes = ""

    // MARK: - UI State

    @State private var showingPreview = false
    @State private var generatedInvoice: Invoice?
    @State private var showingShareSheet = false
    @State private var pdfData: Data?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var viewAppeared = false

    var body: some View {
        NavigationStack {
            Form {
                clientSection
                lineItemsSection
                totalsSection
                optionsSection
                actionsSection
                downloadAppSection
            }
            .navigationTitle("Quick Invoice")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                withAnimation(FLOAnimation.standard) {
                    viewAppeared = true
                }
                AccessibilityAnnouncement.screenChanged("Quick invoice generator")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingPreview) {
                if let invoice = generatedInvoice {
                    InvoiceClipPreviewView(
                        invoice: invoice,
                        pdfData: pdfData
                    )
                }
            }
        }
    }

    // MARK: - Client Section

    private var clientSection: some View {
        Section {
            TextField("Client / Company Name", text: $clientName)
                .textContentType(.organizationName)
                .accessibilityLabel("Client name")

            TextField("Client Email (optional)", text: $clientEmail)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .accessibilityLabel("Client email")
        } header: {
            Text("Bill To")
        }
    }

    // MARK: - Line Items Section

    private var lineItemsSection: some View {
        Section {
            ForEach($lineItems) { $item in
                VStack(spacing: 8) {
                    TextField("Description", text: $item.description)
                        .accessibilityLabel("Item description")

                    HStack(spacing: 12) {
                        HStack {
                            Text("Qty")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("1", value: $item.quantity, format: .number)
                                .keyboardType(.decimalPad)
                                .frame(width: 50)
                                .accessibilityLabel("Quantity")
                        }

                        HStack {
                            Text("$")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("0.00", value: $item.unitPrice, format: .number.precision(.fractionLength(2)))
                                .keyboardType(.decimalPad)
                                .accessibilityLabel("Unit price")
                        }

                        Spacer()

                        Text(item.total, format: .currency(code: "USD"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .accessibilityLabel("Line total: \(item.total.formatted(.currency(code: "USD")))")
                    }
                }
                .padding(.vertical, 4)
            }
            .onDelete { indices in
                lineItems.remove(atOffsets: indices)
                if lineItems.isEmpty {
                    lineItems.append(QuickLineItem())
                }
            }

            Button {
                HapticService.play(.light)
                lineItems.append(QuickLineItem())
            } label: {
                Label("Add Item", systemImage: "plus.circle")
            }
            .accessibilityHint("Add another line item to the invoice")
        } header: {
            Text("Items")
        }
    }

    // MARK: - Totals Section

    private var totalsSection: some View {
        Section {
            HStack {
                Text("Subtotal")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(subtotal, format: .currency(code: "USD"))
                    .fontWeight(.medium)
            }
            .accessibilityElement(children: .combine)

            if taxRate > 0 {
                HStack {
                    Text("Tax (\(taxRate * 100, specifier: "%.1f")%)")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(taxAmount, format: .currency(code: "USD"))
                        .fontWeight(.medium)
                }
                .accessibilityElement(children: .combine)
            }

            HStack {
                Text("Total")
                    .font(.headline)
                Spacer()
                Text(total, format: .currency(code: "USD"))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.brandPrimary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Invoice total: \(total.formatted(.currency(code: "USD")))")
        } header: {
            Text("Summary")
        }
    }

    // MARK: - Options Section

    private var optionsSection: some View {
        Section {
            Picker("Payment Terms", selection: $paymentTermsDays) {
                Text("Due on Receipt").tag(0)
                Text("Net 15").tag(15)
                Text("Net 30").tag(30)
                Text("Net 60").tag(60)
            }

            HStack {
                Text("Tax Rate")
                Spacer()
                TextField("0", value: $taxRate, format: .percent)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }

            TextField("Notes (optional)", text: $notes, axis: .vertical)
                .lineLimit(3)
        } header: {
            Text("Options")
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        Section {
            Button {
                HapticService.play(.medium)
                generateAndPreview()
            } label: {
                Label("Generate Invoice", systemImage: "doc.text.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.brandPrimary)
            .disabled(clientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || validLineItems.isEmpty)
            .accessibilityHint("Creates a PDF invoice with the entered details")
        }
        .listRowBackground(Color.clear)
    }

    // MARK: - Download App Section

    private var downloadAppSection: some View {
        Section {
            VStack(spacing: 8) {
                Image(systemName: "arrow.down.app.fill")
                    .font(.title2)
                    .foregroundStyle(Color.brandPrimary)
                    .accessibilityHidden(true)

                Text("Get the full FLO app for recurring invoices, payment tracking, expense management, and more.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } header: {
            Text("Want More?")
        }
    }

    // MARK: - Computed Properties

    private var validLineItems: [QuickLineItem] {
        lineItems.filter { !$0.description.isEmpty && $0.unitPrice > 0 }
    }

    private var subtotal: Double {
        lineItems.reduce(0) { $0 + $1.total }
    }

    private var taxAmount: Double {
        subtotal * taxRate
    }

    private var total: Double {
        subtotal + taxAmount
    }

    // MARK: - Invoice Generation

    private func generateAndPreview() {
        let trimmedName = clientName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Please enter a client name."
            showingError = true
            return
        }

        guard !validLineItems.isEmpty else {
            errorMessage = "Please add at least one item with a description and price."
            showingError = true
            return
        }

        do {
            let client = findOrCreateClient(name: trimmedName)
            let invoice = try createInvoice(for: client)
            let pdf = try InvoiceService.shared.generatePDF(for: invoice, context: context)

            generatedInvoice = invoice
            pdfData = pdf
            showingPreview = true

            HapticService.play(.success)
            AccessibilityAnnouncement.announce("Invoice generated successfully")

        } catch {
            errorMessage = "Failed to generate invoice: \(error.localizedDescription)"
            showingError = true
            HapticService.play(.error)
        }
    }

    private func findOrCreateClient(name: String) -> Client {
        let descriptor = FetchDescriptor<Client>(
            predicate: #Predicate<Client> { $0.name == name }
        )

        if let existing = try? context.fetch(descriptor).first {
            return existing
        }

        let client = Client(
            name: name,
            email: clientEmail.isEmpty ? nil : clientEmail
        )
        context.insert(client)
        return client
    }

    private func createInvoice(for client: Client) throws -> Invoice {
        let allInvoices = (try? context.fetch(FetchDescriptor<Invoice>())) ?? []
        let invoiceNumber = Invoice.generateNextInvoiceNumber(existingInvoices: allInvoices)

        let paymentTermsLabel = paymentTermsDays == 0 ? "Due on Receipt" : "Net \(paymentTermsDays)"
        let dueDate = Calendar.current.date(byAdding: .day, value: max(paymentTermsDays, 1), to: Date()) ?? Date()

        let invoice = Invoice(
            invoiceNumber: invoiceNumber,
            client: client,
            dueDate: dueDate,
            paymentTerms: paymentTermsLabel,
            taxRate: taxRate,
            notes: notes.isEmpty ? nil : notes
        )

        context.insert(invoice)

        for item in validLineItems {
            let invoiceItem = InvoiceItem(
                invoice: invoice,
                itemDescription: item.description,
                quantity: item.quantity,
                unitPrice: item.unitPrice
            )
            context.insert(invoiceItem)
            if invoice.items != nil {
                invoice.items?.append(invoiceItem)
            } else {
                invoice.items = [invoiceItem]
            }
        }

        try context.save()
        return invoice
    }
}

// MARK: - Quick Line Item Model

struct QuickLineItem: Identifiable {
    let id = UUID()
    var description: String = ""
    var quantity: Double = 1
    var unitPrice: Double = 0

    var total: Double {
        quantity * unitPrice
    }
}
