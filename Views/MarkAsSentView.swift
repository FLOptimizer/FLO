//  MarkAsSentView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.4 - Accessibility Audit: Full VoiceOver support
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v2.4:
//  ✅ ADDED: Header icon + title decorative/grouped for VoiceOver
//  ✅ ADDED: Invoice summary card accessible (client, amount, due date combined)
//  ✅ ADDED: Sent date picker accessible with spoken date
//  ✅ ADDED: Due date info accessible with days until due + urgency
//  ✅ ADDED: Mark as Sent button labeled with hint
//  ✅ ADDED: Share Invoice PDF button labeled with hint
//  ✅ ADDED: Cancel toolbar button labeled
//  ✅ ADDED: Screen change announcement on appear
//  ✅ ADDED: Mark as sent success announced
//  ✅ ADDED: Decorative icons hidden
//
//  CHANGES v2.3:
//  - Migrated to centralized HapticService
//  - Updated shareInvoicePDF() with do/try/catch
//

import SwiftUI
import SwiftData

struct MarkAsSentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let invoice: Invoice
    
    @State private var sentDate = Date()
    @State private var showingShareSheet = false
    @State private var showingPDFError = false
    @State private var isMarking = false
    @State private var showingSuccess = false
    @State private var pdfURL: URL?
    
    // Animation States
    @State private var headerScale: CGFloat = 0.5
    @State private var headerOpacity: Double = 0
    @State private var cardOffset: CGFloat = 30
    @State private var cardOpacity: Double = 0
    @State private var buttonsOffset: CGFloat = 20
    @State private var buttonsOpacity: Double = 0
    @State private var iconRotation: Double = 0
    @State private var markButtonPressed = false
    @State private var shareButtonPressed = false
    @State private var flyAway = false
    
    private var daysUntilDue: Int {
        Calendar.current.dateComponents([.day], from: sentDate, to: invoice.dueDate).day ?? 0
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    ZStack {
                        // Background glow
                        Circle()
                            .fill(Color.brandPrimary.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .blur(radius: 10)
                            .scaleEffect(headerScale * 1.2)
                        
                        Image(systemName: "paperplane.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.brandPrimaryText)
                            .rotationEffect(.degrees(iconRotation))
                            .offset(x: flyAway ? 200 : 0, y: flyAway ? -200 : 0)
                            .opacity(flyAway ? 0 : 1)
                    }
                    .scaleEffect(headerScale)
                    .opacity(headerOpacity)
                    // v2.4: Decorative icon
                    .accessibilityHidden(true)
                    
                    Text("Send Invoice")
                        .font(.title2)
                        .fontWeight(.bold)
                        .scaleEffect(headerScale)
                        .opacity(headerOpacity)
                    
                    Text(invoice.invoiceNumber)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .opacity(headerOpacity)
                }
                .padding(.top, 20)
                // v2.4: Group header for VoiceOver
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Send Invoice \(invoice.invoiceNumber)")
                .accessibilityAddTraits(.isHeader)
                
                // Invoice Summary
                VStack(spacing: 16) {
                    // Client & Amount
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Client")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(invoice.client?.name ?? "No Client")
                                .font(.body)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Amount")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(invoice.totalAmount.formatted(.currency(code: "USD")))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.brandPrimaryText)
                        }
                    }
                    // v2.4: Client and amount grouped
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Invoice for \(invoice.client?.name ?? "no client"), \(AccessibilityFormatters.spokenCurrency(invoice.totalAmount))")
                    
                    Divider()
                    
                    // Date Picker
                    DatePicker(
                        "Sent Date",
                        selection: $sentDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .onChange(of: sentDate) { _, _ in
                        HapticService.shared.selection()
                    }
                    // v2.4: VoiceOver
                    .accessibilityValue(AccessibilityFormatters.spokenDate(sentDate))
                    
                    Divider()
                    
                    // Due Date Info
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                            // v2.4: Decorative
                            .accessibilityHidden(true)
                        
                        Text("Due: \(invoice.dueDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            if daysUntilDue <= 7 {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                    // v2.4: Decorative (status conveyed in parent)
                                    .accessibilityHidden(true)
                            }
                            Text("\(daysUntilDue) days")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(daysUntilDue <= 7 ? .orange : .secondary)
                        }
                    }
                    // v2.4: Due date accessible
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Due \(AccessibilityFormatters.spokenDate(invoice.dueDate)), \(daysUntilDue) days\(daysUntilDue <= 7 ? ", due soon" : "")")
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                .offset(y: cardOffset)
                .opacity(cardOpacity)
                
                Spacer()
                
                // Actions
                VStack(spacing: 12) {
                    // Mark as Sent Button
                    Button {
                        markAsSent()
                    } label: {
                        HStack {
                            if isMarking {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .symbolEffect(.bounce, value: markButtonPressed)
                            }
                            Text("Mark as Sent")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.brandPrimary)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                        .scaleEffect(markButtonPressed ? 0.95 : 1.0)
                    }
                    .disabled(isMarking)
                    .buttonStyle(.plain)
                    // v2.4: VoiceOver
                    .accessibilityLabel("Mark as sent")
                    .accessibilityHint("Double tap to mark this invoice as sent on \(AccessibilityFormatters.spokenDate(sentDate))")
                    
                    // Share Invoice PDF Button
                    Button {
                        shareInvoicePDF()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Invoice PDF")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .foregroundStyle(Color.brandPrimaryText)
                        .cornerRadius(12)
                        .scaleEffect(shareButtonPressed ? 0.95 : 1.0)
                    }
                    .buttonStyle(.plain)
                    // v2.4: VoiceOver
                    .accessibilityLabel("Share invoice PDF")
                    .accessibilityHint("Double tap to generate and share the invoice as a PDF file")
                }
                .padding(.horizontal)
                .padding(.bottom)
                .offset(y: buttonsOffset)
                .opacity(buttonsOpacity)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticService.play(.medium)
                        dismiss()
                    }
                    // v2.4: VoiceOver
                    .accessibilityLabel("Cancel")
                    .accessibilityHint("Double tap to go back without sending")
                }
            }
            .onAppear {
                animateEntrance()
                // v2.4: Announce screen
                AccessibilityAnnouncement.screenChanged("Send Invoice \(invoice.invoiceNumber)")
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = pdfURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("Invoice Sent!", isPresented: $showingSuccess) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text("Invoice \(invoice.invoiceNumber) has been marked as sent on \(sentDate.formatted(date: .abbreviated, time: .omitted)).\n\nPayment due in \(daysUntilDue) days.")
            }
            .alert("PDF Generation Failed", isPresented: $showingPDFError) {
                Button("OK") { }
            } message: {
                Text("Unable to generate the invoice PDF. Please ensure the invoice has at least one line item and try again.")
            }
        }
    }
    
    // MARK: - Animations
    
    private func animateEntrance() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            headerScale = 1.0
            headerOpacity = 1.0
        }
        
        withAnimation(.easeInOut(duration: 0.6).delay(0.2)) {
            iconRotation = 15
        }
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.15)) {
            cardOffset = 0
            cardOpacity = 1.0
        }
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.25)) {
            buttonsOffset = 0
            buttonsOpacity = 1.0
        }
    }
    
    // MARK: - Actions
    
    private func markAsSent() {
        HapticService.play(.heavy)
        
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            markButtonPressed = true
        }
        
        isMarking = true
        
        withAnimation(.easeIn(duration: 0.5)) {
            flyAway = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                markButtonPressed = false
            }
        }
        
        invoice.markAsSent(date: sentDate)
        
        do {
            try modelContext.save()
            
            HapticService.shared.success()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                HapticService.play(.heavy)
            }
            
            // v2.4: Announce success
            AccessibilityAnnouncement.announce("Invoice \(invoice.invoiceNumber) marked as sent")
            
            showingSuccess = true
            
            #if DEBUG
            print("✅ Invoice marked as sent: \(invoice.invoiceNumber)")
            #endif
            
        } catch {
            print("Failed to mark invoice as sent: \(error)")
            
            HapticService.shared.error()
            AccessibilityAnnouncement.announce("Failed to mark invoice as sent")
            
            isMarking = false
            
            withAnimation(FLOAnimation.quick) {
                flyAway = false
            }
        }
    }
    
    /// Generate and share invoice as PDF
    private func shareInvoicePDF() {
        HapticService.play(.medium)
        
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            shareButtonPressed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                shareButtonPressed = false
            }
        }
        
        do {
            let url = try InvoiceService.shared.savePDFToTemporaryFile(for: invoice, context: modelContext)
            pdfURL = url
            
            HapticService.shared.success()
            
            showingShareSheet = true
            
            #if DEBUG
            print("✅ PDF generated for invoice: \(invoice.invoiceNumber)")
            #endif
        } catch {
            HapticService.shared.error()
            AccessibilityAnnouncement.announce("Failed to generate PDF")
            
            showingPDFError = true
            
            #if DEBUG
            print("Failed to generate PDF for invoice: \(invoice.invoiceNumber) - \(error)")
            #endif
        }
    }
}

// MARK: - Preview

#Preview {
    let container = try! ModelContainer(
        for: Invoice.self, Client.self, InvoiceItem.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    let client = Client(name: "Acme Corporation", email: "billing@acme.com")
    container.mainContext.insert(client)
    
    let invoice = Invoice(
        invoiceNumber: "INV-2026-001",
        client: client,
        issueDate: Date(),
        dueDate: Calendar.current.date(byAdding: .day, value: 15, to: Date())!
    )
    
    let item = InvoiceItem(
        invoice: invoice,
        itemDescription: "Website Design",
        quantity: 1,
        unitPrice: 5000
    )
    invoice.items.append(item)
    container.mainContext.insert(invoice)
    
    return MarkAsSentView(invoice: invoice)
        .modelContainer(container)
}

#Preview("Due Soon") {
    let container = try! ModelContainer(
        for: Invoice.self, Client.self, InvoiceItem.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    let client = Client(name: "Urgent Client", email: "urgent@example.com")
    container.mainContext.insert(client)
    
    let invoice = Invoice(
        invoiceNumber: "INV-2026-URGENT",
        client: client,
        issueDate: Date(),
        dueDate: Calendar.current.date(byAdding: .day, value: 3, to: Date())!
    )
    
    let item = InvoiceItem(
        invoice: invoice,
        itemDescription: "Rush Project",
        quantity: 1,
        unitPrice: 2500
    )
    invoice.items.append(item)
    container.mainContext.insert(invoice)
    
    return MarkAsSentView(invoice: invoice)
        .modelContainer(container)
}
