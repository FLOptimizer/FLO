//  SpotlightIndexingService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - CoreSpotlight indexing for transactions, invoices, clients
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Indexes key FLO entities in Spotlight for system-wide search.
//  Users can find transactions, invoices, and clients directly from
//  the iOS home screen search. Tapping a result deep-links into FLO.
//
//  Indexed entities:
//  ✅ Transactions - merchant, amount, date, category
//  ✅ Invoices - client name, invoice number, amount, status
//  ✅ Clients - name, email, phone, company info
//
//  Deep link format: flo://transactions/detail?id=xxx
//                    flo://invoices/detail?id=xxx
//                    flo://more/clients/detail?id=xxx

import CoreSpotlight
import MobileCoreServices
import SwiftData
import Foundation

// MARK: - SpotlightIndexingService

/// Manages CoreSpotlight indexing for FLO entities.
/// Call `reindexAll(modelContext:)` on app launch and
/// `indexTransaction/indexInvoice/indexClient` on individual saves.
@MainActor
final class SpotlightIndexingService {
    
    static let shared = SpotlightIndexingService()
    
    // MARK: - Domain Identifiers
    
    /// Domain identifiers for batch management
    private enum Domain {
        static let transactions = "com.finchandpoppy.flo.transactions"
        static let invoices = "com.finchandpoppy.flo.invoices"
        static let clients = "com.finchandpoppy.flo.clients"
    }
    
    // MARK: - Unique ID Prefixes
    
    /// Prefix for searchable item unique identifiers
    private enum Prefix {
        static let transaction = "flo.transaction."
        static let invoice = "flo.invoice."
        static let client = "flo.client."
    }
    
    private let searchableIndex = CSSearchableIndex.default()
    
    /// Currency formatter for display amounts
    private let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        return f
    }()
    
    /// Date formatter for display dates
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
    
    private init() {}
    
    // MARK: - Full Reindex
    
    /// Reindex all entities. Call on app launch or after bulk data changes.
    func reindexAll(modelContext: ModelContext) {
        Task {
            do {
                // Fetch all entities
                let transactions = try modelContext.fetch(FetchDescriptor<Transaction>())
                let invoices = try modelContext.fetch(FetchDescriptor<Invoice>())
                let clients = try modelContext.fetch(FetchDescriptor<Client>())
                
                // Build searchable items
                var items: [CSSearchableItem] = []
                items.reserveCapacity(transactions.count + invoices.count + clients.count)
                
                for transaction in transactions {
                    if let item = makeSearchableItem(for: transaction) {
                        items.append(item)
                    }
                }
                
                for invoice in invoices {
                    if let item = makeSearchableItem(for: invoice) {
                        items.append(item)
                    }
                }
                
                for client in clients {
                    if let item = makeSearchableItem(for: client) {
                        items.append(item)
                    }
                }
                
                // Delete old index and reindex
                try await searchableIndex.deleteAllSearchableItems()
                try await searchableIndex.indexSearchableItems(items)
                
                print("✅ Spotlight: indexed \(transactions.count) transactions, \(invoices.count) invoices, \(clients.count) clients")
                
            } catch {
                print("⚠️ Spotlight reindex failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Individual Indexing
    
    /// Index or update a single transaction in Spotlight.
    func indexTransaction(_ transaction: Transaction) {
        guard let item = makeSearchableItem(for: transaction) else { return }
        Task {
            do {
                try await searchableIndex.indexSearchableItems([item])
            } catch {
                print("⚠️ Spotlight: failed to index transaction \(transaction.id): \(error.localizedDescription)")
            }
        }
    }
    
    /// Index or update a single invoice in Spotlight.
    func indexInvoice(_ invoice: Invoice) {
        guard let item = makeSearchableItem(for: invoice) else { return }
        Task {
            do {
                try await searchableIndex.indexSearchableItems([item])
            } catch {
                print("⚠️ Spotlight: failed to index invoice \(invoice.id): \(error.localizedDescription)")
            }
        }
    }
    
    /// Index or update a single client in Spotlight.
    func indexClient(_ client: Client) {
        guard let item = makeSearchableItem(for: client) else { return }
        Task {
            do {
                try await searchableIndex.indexSearchableItems([item])
            } catch {
                print("⚠️ Spotlight: failed to index client \(client.id): \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Deletion
    
    /// Remove a transaction from Spotlight index.
    func removeTransaction(id: UUID) {
        let identifier = Prefix.transaction + id.uuidString
        Task {
            do {
                try await searchableIndex.deleteSearchableItems(withIdentifiers: [identifier])
            } catch {
                print("⚠️ Spotlight: failed to remove transaction \(id): \(error.localizedDescription)")
            }
        }
    }
    
    /// Remove an invoice from Spotlight index.
    func removeInvoice(id: UUID) {
        let identifier = Prefix.invoice + id.uuidString
        Task {
            do {
                try await searchableIndex.deleteSearchableItems(withIdentifiers: [identifier])
            } catch {
                print("⚠️ Spotlight: failed to remove invoice \(id): \(error.localizedDescription)")
            }
        }
    }
    
    /// Remove a client from Spotlight index.
    func removeClient(id: UUID) {
        let identifier = Prefix.client + id.uuidString
        Task {
            do {
                try await searchableIndex.deleteSearchableItems(withIdentifiers: [identifier])
            } catch {
                print("⚠️ Spotlight: failed to remove client \(id): \(error.localizedDescription)")
            }
        }
    }
    
    /// Remove all indexed items (e.g., on logout or data reset).
    func removeAll() {
        Task {
            do {
                try await searchableIndex.deleteAllSearchableItems()
                print("✅ Spotlight: cleared all indexed items")
            } catch {
                print("⚠️ Spotlight: failed to clear index: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Deep Link Resolution
    
    /// Parse a Spotlight unique identifier into a deep link URL.
    /// Returns nil if the identifier isn't a FLO Spotlight item.
    func deepLinkURL(for uniqueIdentifier: String) -> URL? {
        if uniqueIdentifier.hasPrefix(Prefix.transaction) {
            let idString = String(uniqueIdentifier.dropFirst(Prefix.transaction.count))
            return URL(string: "flo://transactions/detail?id=\(idString)")
        }
        
        if uniqueIdentifier.hasPrefix(Prefix.invoice) {
            let idString = String(uniqueIdentifier.dropFirst(Prefix.invoice.count))
            return URL(string: "flo://invoices/detail?id=\(idString)")
        }
        
        if uniqueIdentifier.hasPrefix(Prefix.client) {
            let idString = String(uniqueIdentifier.dropFirst(Prefix.client.count))
            // Navigate to More tab > Clients > Client Detail
            return URL(string: "flo://more/clients/detail?id=\(idString)")
        }
        
        return nil
    }
    
    // MARK: - Searchable Item Builders
    
    /// Build a CSSearchableItem for a Transaction.
    private func makeSearchableItem(for transaction: Transaction) -> CSSearchableItem? {
        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        
        // Title: merchant name or note
        let merchant = transaction.merchantName.isEmpty ? "Transaction" : transaction.merchantName
        let amountString = currencyFormatter.string(from: NSNumber(value: transaction.amount)) ?? String(format: "$%.2f", transaction.amount)
        
        if transaction.isIncome {
            attributes.title = "\(merchant) — +\(amountString)"
        } else {
            attributes.title = "\(merchant) — \(amountString)"
        }
        
        // Description: date + category + business/personal
        var descParts: [String] = []
        descParts.append(dateFormatter.string(from: transaction.date))
        
        if let category = transaction.category {
            descParts.append(category.name)
        }
        
        let typeLabel = transaction.financeType == .business ? "Business" : "Personal"
        descParts.append(typeLabel)
        
        if transaction.isIncome {
            descParts.append("Income")
        } else {
            descParts.append("Expense")
        }
        
        attributes.contentDescription = descParts.joined(separator: " · ")
        
        // Keywords for broader matching
        var keywords = [merchant, typeLabel]
        if let category = transaction.category {
            keywords.append(category.name)
        }
        if !transaction.note.isEmpty {
            keywords.append(transaction.note)
        }
        attributes.keywords = keywords
        
        // Thumbnail icon hint
        attributes.thumbnailData = nil // Could add app icon data here later
        
        let identifier = Prefix.transaction + transaction.id.uuidString
        
        let item = CSSearchableItem(
            uniqueIdentifier: identifier,
            domainIdentifier: Domain.transactions,
            attributeSet: attributes
        )
        
        // Transactions older than 2 years auto-expire from Spotlight
        item.expirationDate = Calendar.current.date(byAdding: .year, value: 2, to: transaction.date)
        
        return item
    }
    
    /// Build a CSSearchableItem for an Invoice.
    private func makeSearchableItem(for invoice: Invoice) -> CSSearchableItem? {
        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        
        // Title: Invoice # + client name
        let clientName = invoice.client?.name ?? "Unknown Client"
        attributes.title = "Invoice \(invoice.invoiceNumber) — \(clientName)"
        
        // Description: amount + status + date
        let amountString = currencyFormatter.string(from: NSNumber(value: invoice.totalAmount)) ?? String(format: "$%.2f", invoice.totalAmount)
        let statusText: String
        switch invoice.status {
        case .draft: statusText = "Draft"
        case .sent: statusText = "Sent"
        case .viewed: statusText = "Viewed"
        case .partiallyPaid: statusText = "Partially Paid"
        case .paid: statusText = "Paid"
        case .overdue: statusText = "Overdue"
        case .cancelled: statusText = "Cancelled"
        }
        
        let dueString = dateFormatter.string(from: invoice.dueDate)
        attributes.contentDescription = "\(amountString) · \(statusText) · Due \(dueString)"
        
        // Keywords
        var keywords = [clientName, invoice.invoiceNumber, statusText]
        if let notes = invoice.notes, !notes.isEmpty {
            keywords.append(notes)
        }
        attributes.keywords = keywords
        
        let identifier = Prefix.invoice + invoice.id.uuidString
        
        let item = CSSearchableItem(
            uniqueIdentifier: identifier,
            domainIdentifier: Domain.invoices,
            attributeSet: attributes
        )
        
        // Invoices expire from Spotlight after 3 years
        item.expirationDate = Calendar.current.date(byAdding: .year, value: 3, to: invoice.issueDate)
        
        return item
    }
    
    /// Build a CSSearchableItem for a Client.
    private func makeSearchableItem(for client: Client) -> CSSearchableItem? {
        let attributes = CSSearchableItemAttributeSet(contentType: .contact)
        
        // Title: client/business name
        attributes.title = client.name
        
        // Description: contact info summary
        var descParts: [String] = []
        if let contactName = client.contactName, !contactName.isEmpty {
            descParts.append(contactName)
        }
        if let email = client.email, !email.isEmpty {
            descParts.append(email)
        }
        if let phone = client.phone, !phone.isEmpty {
            descParts.append(phone)
        }
        
        let invoiceCount = client.invoices?.count ?? 0
        if invoiceCount > 0 {
            descParts.append("\(invoiceCount) invoice\(invoiceCount == 1 ? "" : "s")")
        }
        
        attributes.contentDescription = descParts.isEmpty ? "Client" : descParts.joined(separator: " · ")
        
        // Contact-specific attributes
        if let email = client.email {
            attributes.emailAddresses = [email]
        }
        if let phone = client.phone {
            attributes.phoneNumbers = [phone]
        }
        
        // Keywords
        var keywords = [client.name]
        if let contactName = client.contactName, !contactName.isEmpty {
            keywords.append(contactName)
        }
        if let notes = client.notes, !notes.isEmpty {
            keywords.append(notes)
        }
        attributes.keywords = keywords
        
        let identifier = Prefix.client + client.id.uuidString
        
        let item = CSSearchableItem(
            uniqueIdentifier: identifier,
            domainIdentifier: Domain.clients,
            attributeSet: attributes
        )
        
        // Clients don't expire from Spotlight
        item.expirationDate = nil
        
        return item
    }
}
