//  InvoiceClipPreviewView.swift
//  FLO Invoice Clip
//
//  Version 1.0 - Invoice Preview & Share
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE:
//  Displays the generated invoice with summary and provides sharing options.
//  Shows key invoice details and allows PDF export via ShareLink.
//
//  FEATURES v1.0:
//  ✅ Invoice summary display (number, client, total, due date)
//  ✅ Line items list
//  ✅ PDF sharing via ShareLink
//  ✅ VoiceOver accessibility support
//  ✅ Dynamic Type support

import SwiftUI

struct InvoiceClipPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let invoice: Invoice
    let pdfData: Data?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    successBanner
                    invoiceSummary
                    lineItemsList
                    shareSection
                }
                .padding()
            }
            .navigationTitle("Invoice Ready")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                AccessibilityAnnouncement.screenChanged("Invoice preview")
            }
        }
    }

    // MARK: - Success Banner

    private var successBanner: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
                .accessibilityHidden(true)

            Text("Invoice Created")
                .font(.title2)
                .fontWeight(.bold)

            Text(invoice.invoiceNumber)
                .font(.headline)
                .foregroundStyle(.secondary)
                .fontDesign(.monospaced)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.green.opacity(0.08))
        .cornerRadius(16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Invoice \(invoice.invoiceNumber) created successfully")
    }

    // MARK: - Invoice Summary

    private var invoiceSummary: some View {
        VStack(spacing: 12) {
            Text("Summary")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            summaryRow(label: "Client", value: invoice.client?.name ?? "Unknown")
            summaryRow(label: "Invoice #", value: invoice.invoiceNumber)
            summaryRow(label: "Issue Date", value: invoice.issueDate.formatted(date: .abbreviated, time: .omitted))
            summaryRow(label: "Due Date", value: invoice.dueDate.formatted(date: .abbreviated, time: .omitted))
            summaryRow(label: "Terms", value: invoice.paymentTerms)

            Divider()

            HStack {
                Text("Total")
                    .font(.headline)
                Spacer()
                Text(invoice.totalAmount, format: .currency(code: "USD"))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.brandPrimary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Total: \(invoice.totalAmount.formatted(.currency(code: "USD")))")
        }
        .padding()
        .background(Color.floSecondarySystemBackground)
        .cornerRadius(16)
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Line Items

    private var lineItemsList: some View {
        VStack(spacing: 12) {
            Text("Items")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            ForEach(invoice.items ?? []) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.itemDescription)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                        Text("\(item.quantity.formatted()) x \(item.unitPrice.formatted(.currency(code: "USD")))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(item.total, format: .currency(code: "USD"))
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            }

            if invoice.taxRate > 0 {
                Divider()
                HStack {
                    Text("Tax (\(invoice.taxRate * 100, specifier: "%.1f")%)")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(invoice.taxAmount, format: .currency(code: "USD"))
                        .fontWeight(.medium)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding()
        .background(Color.floSecondarySystemBackground)
        .cornerRadius(16)
    }

    // MARK: - Share Section

    private var shareSection: some View {
        VStack(spacing: 12) {
            if let pdfData {
                ShareLink(
                    item: pdfData,
                    preview: SharePreview(
                        "Invoice \(invoice.invoiceNumber)",
                        image: Image(systemName: "doc.text.fill")
                    )
                ) {
                    Label("Share Invoice PDF", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brandPrimary)
                .accessibilityHint("Opens sharing options for the invoice PDF")
            }

            Button {
                dismiss()
            } label: {
                Label("Create Another", systemImage: "plus.circle")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
        }
    }
}
