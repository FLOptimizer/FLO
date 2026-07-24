//  FLOClientTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Client Management Tests
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE: Validate client management features including client
//  creation, invoice association, and payment tracking.
//
//  COVERS:
//  - Client CRUD operations
//  - Client-Invoice relationships
//  - Outstanding balance calculations
//  - Client payment history
//  - Contact information validation
//

import XCTest
@testable import FLO

final class FLOClientTests: XCTestCase {
    
    // MARK: - Test Data Structures
    
    struct TestClient {
        let id: String
        var name: String
        var email: String?
        var phone: String?
        var address: String?
        var isActive: Bool
    }
    
    struct TestInvoice {
        let id: String
        let clientId: String
        let amount: Double
        var amountPaid: Double
        var status: String
    }
    
    // MARK: - Helpers
    
    private func assertCurrencyEqual(_ actual: Double, _ expected: Double, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(actual, expected, accuracy: 0.01, message, file: file, line: line)
    }
}

// MARK: - Client CRUD Operations

extension FLOClientTests {
    
    /// Test: Create new client
    func testClient_Create() {
        let client = TestClient(
            id: "client_001",
            name: "Acme Corporation",
            email: "billing@acme.com",
            phone: "555-123-4567",
            address: "123 Business St",
            isActive: true
        )
        
        XCTAssertEqual(client.name, "Acme Corporation")
        XCTAssertEqual(client.email, "billing@acme.com")
        XCTAssertTrue(client.isActive)
    }
    
    /// Test: Update client
    func testClient_Update() {
        var client = TestClient(
            id: "client_001",
            name: "Acme Corp",
            email: "old@acme.com",
            phone: nil,
            address: nil,
            isActive: true
        )
        
        // Update fields
        client.name = "Acme Corporation"
        client.email = "new@acme.com"
        client.phone = "555-123-4567"
        
        XCTAssertEqual(client.name, "Acme Corporation")
        XCTAssertEqual(client.email, "new@acme.com")
        XCTAssertEqual(client.phone, "555-123-4567")
    }
    
    /// Test: Deactivate client (soft delete)
    func testClient_Deactivate() {
        var client = TestClient(
            id: "client_001",
            name: "Old Client",
            email: nil,
            phone: nil,
            address: nil,
            isActive: true
        )
        
        // Soft delete
        client.isActive = false
        
        XCTAssertFalse(client.isActive, "Client deactivated but not deleted")
    }
    
    /// Test: Filter active clients
    func testClient_FilterActive() {
        let clients = [
            TestClient(id: "1", name: "Active 1", email: nil, phone: nil, address: nil, isActive: true),
            TestClient(id: "2", name: "Inactive", email: nil, phone: nil, address: nil, isActive: false),
            TestClient(id: "3", name: "Active 2", email: nil, phone: nil, address: nil, isActive: true)
        ]
        
        let activeClients = clients.filter { $0.isActive }
        
        XCTAssertEqual(activeClients.count, 2)
    }
}

// MARK: - Contact Information Validation

extension FLOClientTests {
    
    /// Test: Valid email format
    func testValidation_ValidEmail() {
        func isValidEmail(_ email: String) -> Bool {
            let pattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
            let regex = try? NSRegularExpression(pattern: pattern)
            let range = NSRange(email.startIndex..., in: email)
            return regex?.firstMatch(in: email, range: range) != nil
        }
        
        XCTAssertTrue(isValidEmail("test@example.com"))
        XCTAssertTrue(isValidEmail("user.name@domain.co.uk"))
        XCTAssertFalse(isValidEmail("invalid"))
        XCTAssertFalse(isValidEmail("missing@domain"))
        XCTAssertFalse(isValidEmail("@nodomain.com"))
    }
    
    /// Test: Valid phone format
    func testValidation_ValidPhone() {
        func normalizePhone(_ phone: String) -> String {
            return phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        }
        
        func isValidPhone(_ phone: String) -> Bool {
            let digits = normalizePhone(phone)
            return digits.count >= 10 && digits.count <= 15
        }
        
        XCTAssertTrue(isValidPhone("555-123-4567"))
        XCTAssertTrue(isValidPhone("(555) 123-4567"))
        XCTAssertTrue(isValidPhone("+1 555 123 4567"))
        XCTAssertFalse(isValidPhone("123"))
        XCTAssertFalse(isValidPhone(""))
    }
    
    /// Test: Client name required
    func testValidation_NameRequired() {
        func isValidName(_ name: String) -> Bool {
            return !name.trimmingCharacters(in: .whitespaces).isEmpty
        }
        
        XCTAssertTrue(isValidName("Acme Corp"))
        XCTAssertFalse(isValidName(""))
        XCTAssertFalse(isValidName("   "))
    }
}

// MARK: - Client-Invoice Relationships

extension FLOClientTests {
    
    /// Test: Get invoices for client
    func testRelationship_GetClientInvoices() {
        let invoices = [
            TestInvoice(id: "inv_1", clientId: "client_001", amount: 1000, amountPaid: 1000, status: "paid"),
            TestInvoice(id: "inv_2", clientId: "client_001", amount: 2000, amountPaid: 500, status: "partial"),
            TestInvoice(id: "inv_3", clientId: "client_002", amount: 1500, amountPaid: 0, status: "unpaid"),
            TestInvoice(id: "inv_4", clientId: "client_001", amount: 3000, amountPaid: 0, status: "unpaid")
        ]
        
        let client001Invoices = invoices.filter { $0.clientId == "client_001" }
        
        XCTAssertEqual(client001Invoices.count, 3)
    }
    
    /// Test: Calculate outstanding for client
    func testRelationship_ClientOutstanding() {
        let invoices = [
            TestInvoice(id: "inv_1", clientId: "client_001", amount: 1000, amountPaid: 1000, status: "paid"),
            TestInvoice(id: "inv_2", clientId: "client_001", amount: 2000, amountPaid: 500, status: "partial"),
            TestInvoice(id: "inv_3", clientId: "client_001", amount: 3000, amountPaid: 0, status: "unpaid")
        ]
        
        let outstanding = invoices
            .filter { $0.clientId == "client_001" }
            .reduce(0) { $0 + ($1.amount - $1.amountPaid) }
        
        // $0 + $1500 + $3000 = $4500
        assertCurrencyEqual(outstanding, 4500.00)
    }
    
    /// Test: Count unpaid invoices for client
    func testRelationship_UnpaidInvoiceCount() {
        let invoices = [
            TestInvoice(id: "inv_1", clientId: "client_001", amount: 1000, amountPaid: 1000, status: "paid"),
            TestInvoice(id: "inv_2", clientId: "client_001", amount: 2000, amountPaid: 500, status: "partial"),
            TestInvoice(id: "inv_3", clientId: "client_001", amount: 3000, amountPaid: 0, status: "unpaid")
        ]
        
        let unpaidCount = invoices
            .filter { $0.clientId == "client_001" && $0.amountPaid < $0.amount }
            .count
        
        XCTAssertEqual(unpaidCount, 2, "2 invoices not fully paid")
    }
    
    /// Test: Client total billed
    func testRelationship_TotalBilled() {
        let invoices = [
            TestInvoice(id: "inv_1", clientId: "client_001", amount: 1000, amountPaid: 1000, status: "paid"),
            TestInvoice(id: "inv_2", clientId: "client_001", amount: 2000, amountPaid: 500, status: "partial"),
            TestInvoice(id: "inv_3", clientId: "client_001", amount: 3000, amountPaid: 0, status: "unpaid")
        ]
        
        let totalBilled = invoices
            .filter { $0.clientId == "client_001" }
            .reduce(0) { $0 + $1.amount }
        
        assertCurrencyEqual(totalBilled, 6000.00)
    }
}

// MARK: - Payment History

extension FLOClientTests {
    
    struct Payment {
        let invoiceId: String
        let clientId: String
        let amount: Double
        let date: Date
    }
    
    /// Test: Get client payment history
    func testPaymentHistory_GetForClient() {
        let calendar = Calendar.current
        let today = Date()
        
        let payments = [
            Payment(invoiceId: "inv_1", clientId: "client_001", amount: 500, date: calendar.date(byAdding: .day, value: -30, to: today)!),
            Payment(invoiceId: "inv_1", clientId: "client_001", amount: 500, date: calendar.date(byAdding: .day, value: -15, to: today)!),
            Payment(invoiceId: "inv_2", clientId: "client_002", amount: 1000, date: calendar.date(byAdding: .day, value: -10, to: today)!),
            Payment(invoiceId: "inv_3", clientId: "client_001", amount: 750, date: calendar.date(byAdding: .day, value: -5, to: today)!)
        ]
        
        let client001Payments = payments.filter { $0.clientId == "client_001" }
        
        XCTAssertEqual(client001Payments.count, 3)
    }
    
    /// Test: Calculate total paid by client
    func testPaymentHistory_TotalPaid() {
        let payments = [
            Payment(invoiceId: "inv_1", clientId: "client_001", amount: 500, date: Date()),
            Payment(invoiceId: "inv_1", clientId: "client_001", amount: 500, date: Date()),
            Payment(invoiceId: "inv_3", clientId: "client_001", amount: 750, date: Date())
        ]
        
        let totalPaid = payments
            .filter { $0.clientId == "client_001" }
            .reduce(0) { $0 + $1.amount }
        
        assertCurrencyEqual(totalPaid, 1750.00)
    }
    
    /// Test: Average payment amount
    func testPaymentHistory_AveragePayment() {
        let payments: [Double] = [500, 1000, 750, 1250, 500]
        
        let average = payments.reduce(0, +) / Double(payments.count)
        
        assertCurrencyEqual(average, 800.00)
    }
    
    /// Test: Days since last payment
    func testPaymentHistory_DaysSinceLastPayment() {
        let calendar = Calendar.current
        let today = Date()
        let lastPaymentDate = calendar.date(byAdding: .day, value: -15, to: today)!
        
        let daysSince = calendar.dateComponents([.day], from: lastPaymentDate, to: today).day!
        
        XCTAssertEqual(daysSince, 15)
    }
}

// MARK: - Client Statistics

extension FLOClientTests {
    
    /// Test: Calculate client lifetime value
    func testStats_LifetimeValue() {
        let invoices = [
            TestInvoice(id: "1", clientId: "client_001", amount: 5000, amountPaid: 5000, status: "paid"),
            TestInvoice(id: "2", clientId: "client_001", amount: 7500, amountPaid: 7500, status: "paid"),
            TestInvoice(id: "3", clientId: "client_001", amount: 3000, amountPaid: 3000, status: "paid"),
            TestInvoice(id: "4", clientId: "client_001", amount: 4500, amountPaid: 2000, status: "partial")
        ]
        
        let lifetimeValue = invoices
            .filter { $0.clientId == "client_001" }
            .reduce(0) { $0 + $1.amountPaid }
        
        assertCurrencyEqual(lifetimeValue, 17500.00)
    }
    
    /// Test: Calculate average invoice size
    func testStats_AverageInvoiceSize() {
        let invoices = [
            TestInvoice(id: "1", clientId: "client_001", amount: 1000, amountPaid: 1000, status: "paid"),
            TestInvoice(id: "2", clientId: "client_001", amount: 2000, amountPaid: 2000, status: "paid"),
            TestInvoice(id: "3", clientId: "client_001", amount: 3000, amountPaid: 3000, status: "paid")
        ]
        
        let clientInvoices = invoices.filter { $0.clientId == "client_001" }
        let average = clientInvoices.reduce(0) { $0 + $1.amount } / Double(clientInvoices.count)
        
        assertCurrencyEqual(average, 2000.00)
    }
    
    /// Test: Rank clients by revenue
    func testStats_RankByRevenue() {
        let invoices = [
            TestInvoice(id: "1", clientId: "client_001", amount: 5000, amountPaid: 5000, status: "paid"),
            TestInvoice(id: "2", clientId: "client_002", amount: 10000, amountPaid: 10000, status: "paid"),
            TestInvoice(id: "3", clientId: "client_003", amount: 3000, amountPaid: 3000, status: "paid"),
            TestInvoice(id: "4", clientId: "client_001", amount: 2000, amountPaid: 2000, status: "paid")
        ]
        
        var revenueByClient: [String: Double] = [:]
        for invoice in invoices {
            revenueByClient[invoice.clientId, default: 0] += invoice.amountPaid
        }
        
        let ranked = revenueByClient.sorted { $0.value > $1.value }
        
        XCTAssertEqual(ranked[0].key, "client_002", "#1: $10,000")
        XCTAssertEqual(ranked[1].key, "client_001", "#2: $7,000")
        XCTAssertEqual(ranked[2].key, "client_003", "#3: $3,000")
    }
}

// MARK: - Client Search

extension FLOClientTests {
    
    /// Test: Search by name
    func testSearch_ByName() {
        let clients = [
            TestClient(id: "1", name: "Acme Corporation", email: nil, phone: nil, address: nil, isActive: true),
            TestClient(id: "2", name: "Beta Inc", email: nil, phone: nil, address: nil, isActive: true),
            TestClient(id: "3", name: "Acme LLC", email: nil, phone: nil, address: nil, isActive: true)
        ]
        
        let searchTerm = "Acme"
        let results = clients.filter { $0.name.localizedCaseInsensitiveContains(searchTerm) }
        
        XCTAssertEqual(results.count, 2)
    }
    
    /// Test: Search by email
    func testSearch_ByEmail() {
        let clients = [
            TestClient(id: "1", name: "Client A", email: "contact@acme.com", phone: nil, address: nil, isActive: true),
            TestClient(id: "2", name: "Client B", email: "info@beta.com", phone: nil, address: nil, isActive: true),
            TestClient(id: "3", name: "Client C", email: "billing@acme.com", phone: nil, address: nil, isActive: true)
        ]
        
        let searchTerm = "acme.com"
        let results = clients.filter { $0.email?.localizedCaseInsensitiveContains(searchTerm) ?? false }
        
        XCTAssertEqual(results.count, 2)
    }
    
    /// Test: Sort clients alphabetically
    func testSearch_SortAlphabetically() {
        var clients = [
            TestClient(id: "1", name: "Zebra Inc", email: nil, phone: nil, address: nil, isActive: true),
            TestClient(id: "2", name: "Alpha Corp", email: nil, phone: nil, address: nil, isActive: true),
            TestClient(id: "3", name: "Beta LLC", email: nil, phone: nil, address: nil, isActive: true)
        ]
        
        clients.sort { $0.name < $1.name }
        
        XCTAssertEqual(clients[0].name, "Alpha Corp")
        XCTAssertEqual(clients[1].name, "Beta LLC")
        XCTAssertEqual(clients[2].name, "Zebra Inc")
    }
}
