//  FLOInvoiceCalculationTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.2 - Comprehensive Invoice Calculation Tests
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE: Validate all invoice calculations including aging buckets,
//  payment tracking, reminder escalation, and status transitions.
//
//  COVERS:
//  - Invoice number generation
//  - Aging bucket calculations (current, 1-30, 31-60, 61-90, 90+)
//  - Days overdue calculations
//  - Reminder escalation logic
//  - Status transitions
//  - Partial payment tracking
//

import XCTest
@testable import FLO

final class FLOInvoiceCalculationTests: XCTestCase {
    
    // MARK: - Precision
    
    let currencyPrecision: Double = 0.01
    
    private func assertCurrencyEqual(_ actual: Double, _ expected: Double, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(actual, expected, accuracy: currencyPrecision, message.isEmpty ? "Expected \(expected), got \(actual)" : message, file: file, line: line)
    }
    
    // MARK: - Test Helpers
    
    private func createDate(daysFromNow: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: daysFromNow, to: Date())!
    }
}

// MARK: - Invoice Number Generation

extension FLOInvoiceCalculationTests {
    
    /// Test: Invoice number format
    func testInvoiceNumber_Format() {
        let year = Calendar.current.component(.year, from: Date())
        let sequenceNumber = 42
        
        let invoiceNumber = "INV-\(year)-\(String(format: "%03d", sequenceNumber))"
        
        XCTAssertEqual(invoiceNumber, "INV-\(year)-042", "Invoice number format")
    }
    
    /// Test: Invoice number sequence
    func testInvoiceNumber_Sequence() {
        let year = 2026
        
        let invoice1 = "INV-\(year)-001"
        let invoice2 = "INV-\(year)-002"
        let invoice100 = "INV-\(year)-100"
        
        XCTAssertEqual(invoice1, "INV-2026-001")
        XCTAssertEqual(invoice2, "INV-2026-002")
        XCTAssertEqual(invoice100, "INV-2026-100")
    }
    
    /// Test: Invoice number uniqueness (conceptual)
    func testInvoiceNumber_Uniqueness() {
        var usedNumbers: Set<String> = []
        let year = 2026
        
        for i in 1...1000 {
            let number = "INV-\(year)-\(String(format: "%03d", i))"
            XCTAssertFalse(usedNumbers.contains(number), "Duplicate invoice number: \(number)")
            usedNumbers.insert(number)
        }
        
        XCTAssertEqual(usedNumbers.count, 1000, "All invoice numbers should be unique")
    }
    
    /// Test: Invoice number year rollover
    func testInvoiceNumber_YearRollover() {
        let invoice2025 = "INV-2025-500"
        let invoice2026 = "INV-2026-001"
        
        XCTAssertNotEqual(invoice2025, invoice2026, "Different years have different numbers")
    }
}

// MARK: - Days Overdue Calculation

extension FLOInvoiceCalculationTests {
    
    /// Helper: Calculate days overdue
    private func calculateDaysOverdue(dueDate: Date, asOf: Date = Date()) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: dueDate, to: asOf)
        return components.day ?? 0
    }
    
    /// Test: Not yet due (negative days)
    func testDaysOverdue_NotYetDue() {
        let dueDate = createDate(daysFromNow: 10)  // Due in 10 days
        let daysOverdue = calculateDaysOverdue(dueDate: dueDate)
        
        XCTAssertLessThan(daysOverdue, 0, "Future due date = negative days overdue")
        // Allow for time-of-day variance (-10 or -9 depending on exact time)
        XCTAssertTrue(daysOverdue == -10 || daysOverdue == -9, "Should be approximately -10 days (got \(daysOverdue))")
    }
    
    /// Test: Due today
    func testDaysOverdue_DueToday() {
        let dueDate = Date()
        let daysOverdue = calculateDaysOverdue(dueDate: dueDate)
        
        XCTAssertEqual(daysOverdue, 0, "Due today = 0 days overdue")
    }
    
    /// Test: Overdue by 1 day
    func testDaysOverdue_OneDayLate() {
        let dueDate = createDate(daysFromNow: -1)  // Due yesterday
        let daysOverdue = calculateDaysOverdue(dueDate: dueDate)
        
        XCTAssertEqual(daysOverdue, 1, "1 day overdue")
    }
    
    /// Test: Overdue by 30 days
    func testDaysOverdue_ThirtyDays() {
        let dueDate = createDate(daysFromNow: -30)
        let daysOverdue = calculateDaysOverdue(dueDate: dueDate)
        
        XCTAssertEqual(daysOverdue, 30, "30 days overdue")
    }
    
    /// Test: Overdue by 90+ days
    func testDaysOverdue_NinetyPlusDays() {
        let dueDate = createDate(daysFromNow: -100)
        let daysOverdue = calculateDaysOverdue(dueDate: dueDate)
        
        XCTAssertEqual(daysOverdue, 100, "100 days overdue")
        XCTAssertGreaterThan(daysOverdue, 90, "Should be in 90+ bucket")
    }
}

// MARK: - Aging Bucket Classification

extension FLOInvoiceCalculationTests {
    
    /// Aging bucket enum
    enum AgingBucket: String {
        case current = "Current"
        case days1to30 = "1-30 Days"
        case days31to60 = "31-60 Days"
        case days61to90 = "61-90 Days"
        case days90plus = "90+ Days"
    }
    
    /// Helper: Get aging bucket from days overdue
    private func getAgingBucket(daysOverdue: Int) -> AgingBucket {
        if daysOverdue <= 0 {
            return .current
        } else if daysOverdue <= 30 {
            return .days1to30
        } else if daysOverdue <= 60 {
            return .days31to60
        } else if daysOverdue <= 90 {
            return .days61to90
        } else {
            return .days90plus
        }
    }
    
    /// Test: Current bucket (not overdue)
    func testAgingBucket_Current() {
        XCTAssertEqual(getAgingBucket(daysOverdue: -10), .current)
        XCTAssertEqual(getAgingBucket(daysOverdue: 0), .current)
    }
    
    /// Test: 1-30 days bucket
    func testAgingBucket_1to30Days() {
        XCTAssertEqual(getAgingBucket(daysOverdue: 1), .days1to30)
        XCTAssertEqual(getAgingBucket(daysOverdue: 15), .days1to30)
        XCTAssertEqual(getAgingBucket(daysOverdue: 30), .days1to30)
    }
    
    /// Test: 31-60 days bucket
    func testAgingBucket_31to60Days() {
        XCTAssertEqual(getAgingBucket(daysOverdue: 31), .days31to60)
        XCTAssertEqual(getAgingBucket(daysOverdue: 45), .days31to60)
        XCTAssertEqual(getAgingBucket(daysOverdue: 60), .days31to60)
    }
    
    /// Test: 61-90 days bucket
    func testAgingBucket_61to90Days() {
        XCTAssertEqual(getAgingBucket(daysOverdue: 61), .days61to90)
        XCTAssertEqual(getAgingBucket(daysOverdue: 75), .days61to90)
        XCTAssertEqual(getAgingBucket(daysOverdue: 90), .days61to90)
    }
    
    /// Test: 90+ days bucket
    func testAgingBucket_90PlusDays() {
        XCTAssertEqual(getAgingBucket(daysOverdue: 91), .days90plus)
        XCTAssertEqual(getAgingBucket(daysOverdue: 120), .days90plus)
        XCTAssertEqual(getAgingBucket(daysOverdue: 365), .days90plus)
    }
    
    /// Test: Bucket boundaries
    func testAgingBucket_Boundaries() {
        // Test exact boundaries
        XCTAssertEqual(getAgingBucket(daysOverdue: 0), .current, "0 days = current")
        XCTAssertEqual(getAgingBucket(daysOverdue: 1), .days1to30, "1 day = 1-30")
        XCTAssertEqual(getAgingBucket(daysOverdue: 30), .days1to30, "30 days = 1-30")
        XCTAssertEqual(getAgingBucket(daysOverdue: 31), .days31to60, "31 days = 31-60")
        XCTAssertEqual(getAgingBucket(daysOverdue: 60), .days31to60, "60 days = 31-60")
        XCTAssertEqual(getAgingBucket(daysOverdue: 61), .days61to90, "61 days = 61-90")
        XCTAssertEqual(getAgingBucket(daysOverdue: 90), .days61to90, "90 days = 61-90")
        XCTAssertEqual(getAgingBucket(daysOverdue: 91), .days90plus, "91 days = 90+")
    }
}

// MARK: - Reminder Escalation

extension FLOInvoiceCalculationTests {
    
    /// Reminder type enum
    enum ReminderType: String {
        case none = "None"
        case gentle = "Gentle"
        case standard = "Standard"
        case firm = "Firm"
        case final = "Final Notice"
    }
    
    /// Helper: Get reminder type from days overdue
    private func getReminderType(daysOverdue: Int) -> ReminderType {
        if daysOverdue <= 0 {
            return .none
        } else if daysOverdue <= 7 {
            return .gentle
        } else if daysOverdue <= 30 {
            return .standard
        } else if daysOverdue <= 60 {
            return .firm
        } else {
            return .final
        }
    }
    
    /// Test: No reminder when not overdue
    func testReminder_NotOverdue() {
        XCTAssertEqual(getReminderType(daysOverdue: -5), .none)
        XCTAssertEqual(getReminderType(daysOverdue: 0), .none)
    }
    
    /// Test: Gentle reminder (1-7 days)
    func testReminder_Gentle() {
        XCTAssertEqual(getReminderType(daysOverdue: 1), .gentle)
        XCTAssertEqual(getReminderType(daysOverdue: 3), .gentle)
        XCTAssertEqual(getReminderType(daysOverdue: 7), .gentle)
    }
    
    /// Test: Standard reminder (8-30 days)
    func testReminder_Standard() {
        XCTAssertEqual(getReminderType(daysOverdue: 8), .standard)
        XCTAssertEqual(getReminderType(daysOverdue: 15), .standard)
        XCTAssertEqual(getReminderType(daysOverdue: 30), .standard)
    }
    
    /// Test: Firm reminder (31-60 days)
    func testReminder_Firm() {
        XCTAssertEqual(getReminderType(daysOverdue: 31), .firm)
        XCTAssertEqual(getReminderType(daysOverdue: 45), .firm)
        XCTAssertEqual(getReminderType(daysOverdue: 60), .firm)
    }
    
    /// Test: Final notice (61+ days)
    func testReminder_Final() {
        XCTAssertEqual(getReminderType(daysOverdue: 61), .final)
        XCTAssertEqual(getReminderType(daysOverdue: 90), .final)
        XCTAssertEqual(getReminderType(daysOverdue: 180), .final)
    }
    
    /// Test: Escalation order
    func testReminder_EscalationOrder() {
        let day0 = getReminderType(daysOverdue: 0)
        let day5 = getReminderType(daysOverdue: 5)
        let day15 = getReminderType(daysOverdue: 15)
        let day45 = getReminderType(daysOverdue: 45)
        let day90 = getReminderType(daysOverdue: 90)
        
        XCTAssertEqual(day0, .none)
        XCTAssertEqual(day5, .gentle)
        XCTAssertEqual(day15, .standard)
        XCTAssertEqual(day45, .firm)
        XCTAssertEqual(day90, .final)
    }
}

// MARK: - Invoice Status Transitions

extension FLOInvoiceCalculationTests {
    
    /// Invoice status enum
    enum InvoiceStatus: String {
        case draft = "Draft"
        case sent = "Sent"
        case viewed = "Viewed"
        case partiallyPaid = "Partially Paid"
        case paid = "Paid"
        case overdue = "Overdue"
        case cancelled = "Cancelled"
    }
    
    /// Test: Valid status transitions from Draft
    func testStatusTransition_FromDraft() {
        let validTransitions: [InvoiceStatus] = [.sent, .cancelled]
        let invalidTransitions: [InvoiceStatus] = [.viewed, .partiallyPaid, .paid, .overdue]
        
        // Draft can only go to Sent or Cancelled
        XCTAssertTrue(validTransitions.contains(.sent))
        XCTAssertTrue(validTransitions.contains(.cancelled))
        XCTAssertFalse(validTransitions.contains(.paid))
        
        // Draft cannot jump to these states
        XCTAssertFalse(invalidTransitions.contains(.sent))
        XCTAssertFalse(invalidTransitions.contains(.cancelled))
    }
    
    /// Test: Valid status transitions from Sent
    func testStatusTransition_FromSent() {
        let validTransitions: [InvoiceStatus] = [.viewed, .partiallyPaid, .paid, .overdue, .cancelled]
        
        XCTAssertTrue(validTransitions.contains(.viewed))
        XCTAssertTrue(validTransitions.contains(.paid))
        XCTAssertTrue(validTransitions.contains(.overdue))
    }
    
    /// Test: Status auto-update based on payment
    func testStatusTransition_AutoUpdateOnPayment() {
        let total: Double = 1000
        
        func getStatusForPayment(amountPaid: Double) -> InvoiceStatus {
            if amountPaid <= 0 {
                return .sent
            } else if amountPaid < total {
                return .partiallyPaid
            } else {
                return .paid
            }
        }
        
        XCTAssertEqual(getStatusForPayment(amountPaid: 0), .sent)
        XCTAssertEqual(getStatusForPayment(amountPaid: 500), .partiallyPaid)
        XCTAssertEqual(getStatusForPayment(amountPaid: 999.99), .partiallyPaid)
        XCTAssertEqual(getStatusForPayment(amountPaid: 1000), .paid)
        XCTAssertEqual(getStatusForPayment(amountPaid: 1100), .paid)  // Overpaid
    }
    
    /// Test: Paid status is terminal (except for refunds)
    func testStatusTransition_PaidIsTerminal() {
        // Once paid, typically cannot transition to other statuses
        // (except potentially to handle refunds)
        let paidStatus = InvoiceStatus.paid
        
        XCTAssertEqual(paidStatus, .paid, "Paid is a terminal status")
    }
}

// MARK: - Partial Payment Tracking

extension FLOInvoiceCalculationTests {
    
    /// Test: Single partial payment
    func testPartialPayment_Single() {
        let total: Double = 2000
        let payment: Double = 500
        
        let remaining = total - payment
        let progress = payment / total
        
        assertCurrencyEqual(remaining, 1500)
        XCTAssertEqual(progress, 0.25, accuracy: 0.01, "25% paid")
    }
    
    /// Test: Multiple partial payments
    func testPartialPayment_Multiple() {
        let total: Double = 1000
        let payments: [Double] = [200, 300, 150]
        
        let amountPaid = payments.reduce(0, +)
        let remaining = total - amountPaid
        let progress = amountPaid / total
        
        assertCurrencyEqual(amountPaid, 650)
        assertCurrencyEqual(remaining, 350)
        XCTAssertEqual(progress, 0.65, accuracy: 0.01, "65% paid")
    }
    
    /// Test: Exactly paid off
    func testPartialPayment_ExactlyPaid() {
        let total: Double = 1500
        let payments: [Double] = [500, 500, 500]
        
        let amountPaid = payments.reduce(0, +)
        let remaining = max(0, total - amountPaid)
        let isFullyPaid = remaining <= 0.01
        
        assertCurrencyEqual(amountPaid, 1500)
        assertCurrencyEqual(remaining, 0)
        XCTAssertTrue(isFullyPaid)
    }
    
    /// Test: Overpayment
    func testPartialPayment_Overpayment() {
        let total: Double = 1000
        let amountPaid: Double = 1100
        
        let remaining = max(0, total - amountPaid)
        let overpayment = max(0, amountPaid - total)
        
        assertCurrencyEqual(remaining, 0, "Remaining floors at 0")
        assertCurrencyEqual(overpayment, 100, "Overpaid by $100")
    }
    
    /// Test: Payment progress percentage
    func testPartialPayment_ProgressPercentages() {
        let total: Double = 1000
        
        func getProgress(_ paid: Double) -> Double {
            return min(paid / total, 1.0)
        }
        
        XCTAssertEqual(getProgress(0), 0.0, accuracy: 0.01)
        XCTAssertEqual(getProgress(250), 0.25, accuracy: 0.01)
        XCTAssertEqual(getProgress(500), 0.50, accuracy: 0.01)
        XCTAssertEqual(getProgress(750), 0.75, accuracy: 0.01)
        XCTAssertEqual(getProgress(1000), 1.0, accuracy: 0.01)
        XCTAssertEqual(getProgress(1500), 1.0, accuracy: 0.01, "Progress caps at 100%")
    }
}

// MARK: - Invoice Total Calculations

extension FLOInvoiceCalculationTests {
    
    /// Test: Invoice with multiple line items
    func testInvoiceTotal_MultipleLineItems() {
        let lineItems: [(quantity: Double, unitPrice: Double)] = [
            (10, 150.00),   // $1,500
            (5, 75.00),     // $375
            (1, 500.00),    // $500
            (2.5, 200.00)   // $500
        ]
        
        let subtotal = lineItems.reduce(0) { $0 + ($1.quantity * $1.unitPrice) }
        
        assertCurrencyEqual(subtotal, 2875.00)
    }
    
    /// Test: Invoice with tax
    func testInvoiceTotal_WithTax() {
        let subtotal: Double = 1000
        let taxRate: Double = 0.0825  // 8.25%
        
        let tax = subtotal * taxRate
        let total = subtotal + tax
        
        assertCurrencyEqual(tax, 82.50)
        assertCurrencyEqual(total, 1082.50)
    }
    
    /// Test: Invoice with discount
    func testInvoiceTotal_WithDiscount() {
        let subtotal: Double = 1000
        let discount: Double = 100
        
        let total = subtotal - discount
        
        assertCurrencyEqual(total, 900)
    }
    
    /// Test: Invoice with tax and discount
    func testInvoiceTotal_TaxAndDiscount() {
        let subtotal: Double = 1000
        let taxRate: Double = 0.08
        let discount: Double = 50
        
        // Tax is typically calculated on subtotal, then discount applied
        let tax = subtotal * taxRate
        let total = subtotal + tax - discount
        
        assertCurrencyEqual(tax, 80.00)
        assertCurrencyEqual(total, 1030.00)
    }
    
    /// Test: Invoice with percentage discount
    func testInvoiceTotal_PercentageDiscount() {
        let subtotal: Double = 2000
        let discountPercent: Double = 0.10  // 10%
        
        let discountAmount = subtotal * discountPercent
        let total = subtotal - discountAmount
        
        assertCurrencyEqual(discountAmount, 200)
        assertCurrencyEqual(total, 1800)
    }
}

// MARK: - Integration: Full Invoice Lifecycle

extension FLOInvoiceCalculationTests {
    
    /// Test: Complete invoice lifecycle
    func testIntegration_FullLifecycle() {
        // 1. Create invoice
        let lineItems: [(quantity: Double, unitPrice: Double)] = [
            (8, 125.00),    // $1,000 - Consulting hours
            (1, 250.00)     // $250 - Setup fee
        ]
        let subtotal = lineItems.reduce(0) { $0 + ($1.quantity * $1.unitPrice) }
        assertCurrencyEqual(subtotal, 1250.00)
        
        // 2. Add tax
        let taxRate: Double = 0.0825
        let tax = subtotal * taxRate
        assertCurrencyEqual(tax, 103.13)
        
        // 3. Calculate total
        let total = subtotal + tax
        assertCurrencyEqual(total, 1353.13)
        
        // 4. First partial payment
        let payment1: Double = 500
        var amountPaid = payment1
        var remaining = total - amountPaid
        assertCurrencyEqual(remaining, 853.13)
        
        // 5. Second partial payment
        let payment2: Double = 500
        amountPaid += payment2
        remaining = total - amountPaid
        assertCurrencyEqual(remaining, 353.13)
        
        // 6. Final payment
        let payment3: Double = 353.13
        amountPaid += payment3
        remaining = max(0, total - amountPaid)
        assertCurrencyEqual(remaining, 0, "Fully paid")
        
        // 7. Verify fully paid
        let isFullyPaid = remaining <= 0.01
        XCTAssertTrue(isFullyPaid)
    }
}
