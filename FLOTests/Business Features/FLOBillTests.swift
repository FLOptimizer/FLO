//  FLOBillTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Bill model + BillService tests
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  COVERS:
//  - Bill status transitions (pending → partiallyPaid → paid)
//  - Partial payment math
//  - Computed isOverdue (with and without Upon Receipt)
//  - effectiveSortDate ordering
//  - BillService.findOrCreateVendor (case-insensitive matching)
//  - BillService.recordPayment full + partial flows
//  - Account balance debit on payment
//  - Validation errors (zero amount, missing vendor, missing date)

import XCTest
import SwiftData
@testable import FLO

@MainActor
final class FLOBillTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = ModelContainer.forTesting()
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    private func date(daysFromNow: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: daysFromNow, to: Date())!
    }

    private func makeAccount(name: String = "Checking", balance: Double = 1000) -> Account {
        let account = Account(name: name, accountType: .checking, currentBalance: balance)
        context.insert(account)
        return account
    }

    // MARK: - Status Transitions

    func testBill_InitiallyPending() {
        let bill = Bill(
            vendorName: "PG&E",
            amount: 100,
            dueDate: date(daysFromNow: 7)
        )
        XCTAssertEqual(bill.status, .pending)
        XCTAssertFalse(bill.hasPayments)
        XCTAssertFalse(bill.isFullyPaid)
        XCTAssertFalse(bill.isPartiallyPaid)
        XCTAssertEqual(bill.amountPaid, 0)
        XCTAssertEqual(bill.remainingBalance, 100)
    }

    func testBill_FullPayment_TransitionsToPaid() {
        let bill = Bill(vendorName: "PG&E", amount: 100, dueDate: date(daysFromNow: 7))
        context.insert(bill)
        let account = makeAccount(balance: 500)

        bill.recordPayment(amount: 100, account: account, in: context)

        XCTAssertEqual(bill.status, .paid)
        XCTAssertTrue(bill.isFullyPaid)
        XCTAssertFalse(bill.isPartiallyPaid)
        XCTAssertEqual(bill.amountPaid, 100, accuracy: 0.01)
        XCTAssertEqual(bill.remainingBalance, 0, accuracy: 0.01)
    }

    func testBill_PartialPayment_TransitionsToPartiallyPaid() {
        let bill = Bill(vendorName: "AmEx", amount: 1000, dueDate: date(daysFromNow: 14))
        context.insert(bill)
        let account = makeAccount(balance: 5000)

        bill.recordPayment(amount: 300, account: account, in: context)

        XCTAssertEqual(bill.status, .partiallyPaid)
        XCTAssertFalse(bill.isFullyPaid)
        XCTAssertTrue(bill.isPartiallyPaid)
        XCTAssertEqual(bill.amountPaid, 300, accuracy: 0.01)
        XCTAssertEqual(bill.remainingBalance, 700, accuracy: 0.01)
    }

    func testBill_MultiplePartialPayments_SumCorrectly() {
        let bill = Bill(vendorName: "AmEx", amount: 1000, dueDate: date(daysFromNow: 14))
        context.insert(bill)
        let account = makeAccount(balance: 5000)

        bill.recordPayment(amount: 300, account: account, in: context)
        bill.recordPayment(amount: 200, account: account, in: context)

        XCTAssertEqual(bill.status, .partiallyPaid)
        XCTAssertEqual(bill.amountPaid, 500, accuracy: 0.01)
        XCTAssertEqual(bill.remainingBalance, 500, accuracy: 0.01)
        XCTAssertEqual(bill.payments?.count, 2)
    }

    func testBill_PartialThenFullPayment_TransitionsToPaid() {
        let bill = Bill(vendorName: "AmEx", amount: 1000, dueDate: date(daysFromNow: 14))
        context.insert(bill)
        let account = makeAccount(balance: 5000)

        bill.recordPayment(amount: 300, account: account, in: context)
        XCTAssertEqual(bill.status, .partiallyPaid)

        bill.recordPayment(amount: 700, account: account, in: context)
        XCTAssertEqual(bill.status, .paid)
        XCTAssertTrue(bill.isFullyPaid)
    }

    func testBill_RoundingTolerance_OneCentBelowFull_StillCountsAsPaid() {
        let bill = Bill(vendorName: "PG&E", amount: 100.00, dueDate: date(daysFromNow: 7))
        context.insert(bill)
        let account = makeAccount(balance: 500)

        bill.recordPayment(amount: 99.995, account: account, in: context)

        XCTAssertTrue(bill.isFullyPaid, "Within 1¢ tolerance should be considered fully paid")
        XCTAssertEqual(bill.status, .paid)
    }

    // MARK: - Account Balance Debit

    func testBill_PaymentDebitsAccountBalance() {
        let bill = Bill(vendorName: "PG&E", amount: 142.58, dueDate: date(daysFromNow: 7))
        context.insert(bill)
        let account = makeAccount(balance: 1000)

        bill.recordPayment(amount: 142.58, account: account, in: context)

        XCTAssertEqual(account.currentBalance, 857.42, accuracy: 0.01)
    }

    func testBill_PaymentCreatesPostedTransaction() {
        let bill = Bill(vendorName: "PG&E", amount: 100, dueDate: date(daysFromNow: 7))
        context.insert(bill)
        let account = makeAccount()

        let result = bill.recordPayment(amount: 100, account: account, in: context)

        XCTAssertEqual(result.transaction.amount, 100, accuracy: 0.01)
        XCTAssertEqual(result.transaction.merchantName, "PG&E")
        XCTAssertFalse(result.transaction.isIncome)
        XCTAssertEqual(result.transaction.account?.id, account.id)
    }

    func testBill_PaymentLinksTransactionToBillPayment() {
        let bill = Bill(vendorName: "PG&E", amount: 100, dueDate: date(daysFromNow: 7))
        context.insert(bill)
        let account = makeAccount()

        let result = bill.recordPayment(amount: 100, account: account, in: context)

        XCTAssertEqual(result.payment.linkedTransaction?.id, result.transaction.id)
        XCTAssertEqual(result.payment.bill?.id, bill.id)
    }

    // MARK: - Overdue Computation

    func testBill_NotOverdue_BeforeDueDate() {
        let bill = Bill(vendorName: "PG&E", amount: 100, dueDate: date(daysFromNow: 5))
        XCTAssertFalse(bill.isOverdue)
    }

    func testBill_Overdue_PastDueDate() {
        let bill = Bill(vendorName: "PG&E", amount: 100, dueDate: date(daysFromNow: -3))
        XCTAssertTrue(bill.isOverdue)
    }

    func testBill_NotOverdue_WhenPaid() {
        let bill = Bill(vendorName: "PG&E", amount: 100, dueDate: date(daysFromNow: -3))
        bill.status = .paid
        XCTAssertFalse(bill.isOverdue, "Paid bills are never overdue")
    }

    func testBill_NotOverdue_WhenCancelled() {
        let bill = Bill(vendorName: "PG&E", amount: 100, dueDate: date(daysFromNow: -3))
        bill.cancel()
        XCTAssertFalse(bill.isOverdue)
    }

    func testBill_PartiallyPaid_StillOverdueIfPastDue() {
        let bill = Bill(vendorName: "AmEx", amount: 1000, dueDate: date(daysFromNow: -2))
        context.insert(bill)
        let account = makeAccount(balance: 5000)

        bill.recordPayment(amount: 300, account: account, in: context)

        XCTAssertEqual(bill.status, .partiallyPaid)
        XCTAssertTrue(bill.isOverdue, "Partially paid bills can still be overdue")
    }

    func testBill_UponReceipt_NotOverdueImmediately() {
        let bill = Bill(
            vendorName: "Smith Plumbing",
            amount: 450,
            isUponReceipt: true
        )
        // Just created - within the 1-day grace
        XCTAssertFalse(bill.isOverdue)
    }

    func testBill_UponReceipt_OverdueAfterOneDay() {
        let bill = Bill(
            vendorName: "Smith Plumbing",
            amount: 450,
            isUponReceipt: true,
            createdDate: date(daysFromNow: -2)
        )
        XCTAssertTrue(bill.isOverdue)
    }

    func testBill_UponReceipt_NoDueDateStored() {
        let bill = Bill(
            vendorName: "Smith Plumbing",
            amount: 450,
            dueDate: date(daysFromNow: 7), // Should be ignored
            isUponReceipt: true
        )
        XCTAssertNil(bill.dueDate, "Upon Receipt bills must not store a due date")
    }

    // MARK: - effectiveSortDate

    func testBill_UponReceipt_SortsToTop() {
        let regular = Bill(vendorName: "PG&E", amount: 100, dueDate: date(daysFromNow: 5))
        let uponReceipt = Bill(vendorName: "Plumber", amount: 200, isUponReceipt: true)

        XCTAssertLessThan(uponReceipt.effectiveSortDate, regular.effectiveSortDate)
    }

    func testBill_EarlierDueDate_SortsBeforeLater() {
        let early = Bill(vendorName: "PG&E", amount: 100, dueDate: date(daysFromNow: 2))
        let late = Bill(vendorName: "Comcast", amount: 80, dueDate: date(daysFromNow: 10))

        XCTAssertLessThan(early.effectiveSortDate, late.effectiveSortDate)
    }

    // MARK: - daysUntilDue

    func testBill_DaysUntilDue_PositiveForFuture() {
        let bill = Bill(vendorName: "PG&E", amount: 100, dueDate: date(daysFromNow: 5))
        XCTAssertEqual(bill.daysUntilDue, 5)
    }

    func testBill_DaysUntilDue_NegativeForPast() {
        let bill = Bill(vendorName: "PG&E", amount: 100, dueDate: date(daysFromNow: -3))
        XCTAssertEqual(bill.daysUntilDue, -3)
    }

    func testBill_DaysUntilDue_NilForUponReceipt() {
        let bill = Bill(vendorName: "Plumber", amount: 200, isUponReceipt: true)
        XCTAssertNil(bill.daysUntilDue)
    }

    // MARK: - BillService.findOrCreateVendor

    func testBillService_FindOrCreateVendor_CreatesWhenMissing() throws {
        let vendor = try BillService.shared.findOrCreateVendor(name: "PG&E", context: context)
        XCTAssertEqual(vendor.name, "PG&E")

        let allVendors = try BillService.shared.fetchAllVendors(context: context)
        XCTAssertEqual(allVendors.count, 1)
    }

    func testBillService_FindOrCreateVendor_ReusesExistingExactMatch() throws {
        let first = try BillService.shared.findOrCreateVendor(name: "PG&E", context: context)
        let second = try BillService.shared.findOrCreateVendor(name: "PG&E", context: context)

        XCTAssertEqual(first.id, second.id)
        let allVendors = try BillService.shared.fetchAllVendors(context: context)
        XCTAssertEqual(allVendors.count, 1)
    }

    func testBillService_FindOrCreateVendor_CaseInsensitiveMatch() throws {
        let first = try BillService.shared.findOrCreateVendor(name: "PG&E", context: context)
        let second = try BillService.shared.findOrCreateVendor(name: "pg&e", context: context)
        let third = try BillService.shared.findOrCreateVendor(name: "Pg&E", context: context)

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.id, third.id)
        let allVendors = try BillService.shared.fetchAllVendors(context: context)
        XCTAssertEqual(allVendors.count, 1, "Case variants should not create duplicate vendors")
    }

    func testBillService_FindOrCreateVendor_TrimsWhitespace() throws {
        let first = try BillService.shared.findOrCreateVendor(name: "PG&E", context: context)
        let second = try BillService.shared.findOrCreateVendor(name: "  PG&E  ", context: context)
        XCTAssertEqual(first.id, second.id)
    }

    func testBillService_FindOrCreateVendor_RejectsEmpty() {
        XCTAssertThrowsError(try BillService.shared.findOrCreateVendor(name: "   ", context: context)) { error in
            guard case BillServiceError.vendorRequired = error else {
                XCTFail("Expected .vendorRequired, got \(error)")
                return
            }
        }
    }

    // MARK: - BillService.createBill

    func testBillService_CreateBill_HappyPath() throws {
        let bill = try BillService.shared.createBill(
            vendorName: "PG&E",
            amount: 142.58,
            dueDate: date(daysFromNow: 7),
            note: "March electric",
            financeType: .personal,
            context: context
        )

        XCTAssertEqual(bill.vendorName, "PG&E")
        XCTAssertEqual(bill.amount, 142.58, accuracy: 0.01)
        XCTAssertEqual(bill.status, .pending)
        XCTAssertNotNil(bill.vendor, "Bill should be linked to a vendor")
        XCTAssertEqual(bill.vendor?.name, "PG&E")
    }

    func testBillService_CreateBill_RejectsZeroAmount() {
        XCTAssertThrowsError(try BillService.shared.createBill(
            vendorName: "PG&E",
            amount: 0,
            dueDate: date(daysFromNow: 7),
            context: context
        ))
    }

    func testBillService_CreateBill_RejectsMissingDueDateAndUponReceipt() {
        XCTAssertThrowsError(try BillService.shared.createBill(
            vendorName: "PG&E",
            amount: 100,
            dueDate: nil,
            isUponReceipt: false,
            context: context
        )) { error in
            guard case BillServiceError.invalidData = error else {
                XCTFail("Expected .invalidData, got \(error)")
                return
            }
        }
    }

    func testBillService_CreateBill_UponReceiptDoesNotRequireDueDate() throws {
        let bill = try BillService.shared.createBill(
            vendorName: "Plumber",
            amount: 450,
            dueDate: nil,
            isUponReceipt: true,
            context: context
        )
        XCTAssertNil(bill.dueDate)
        XCTAssertTrue(bill.isUponReceipt)
    }

    func testBillService_CreateBill_AppliesVendorDefaults() throws {
        // Create a vendor with defaults
        let vendor = try BillService.shared.findOrCreateVendor(name: "PG&E", context: context)
        let category = Category(name: "Utilities", icon: "bolt.fill")
        context.insert(category)
        vendor.defaultCategory = category

        // Create a bill without specifying a category — should inherit from vendor
        let bill = try BillService.shared.createBill(
            vendorName: "PG&E",
            amount: 100,
            dueDate: date(daysFromNow: 7),
            context: context
        )

        XCTAssertEqual(bill.category?.id, category.id, "Bill should inherit vendor's default category")
    }

    // MARK: - BillService.recordPayment

    func testBillService_RecordPayment_FullPayment() throws {
        let bill = try BillService.shared.createBill(
            vendorName: "PG&E",
            amount: 100,
            dueDate: date(daysFromNow: 7),
            context: context
        )
        let account = makeAccount(balance: 500)

        let result = try BillService.shared.recordPayment(
            for: bill,
            account: account,
            context: context
        )

        XCTAssertEqual(bill.status, .paid)
        XCTAssertEqual(result.payment.amount, 100, accuracy: 0.01)
        XCTAssertEqual(account.currentBalance, 400, accuracy: 0.01)
    }

    func testBillService_RecordPayment_PartialPayment() throws {
        let bill = try BillService.shared.createBill(
            vendorName: "AmEx",
            amount: 1000,
            dueDate: date(daysFromNow: 14),
            context: context
        )
        let account = makeAccount(balance: 5000)

        try BillService.shared.recordPayment(
            for: bill,
            amount: 250,
            account: account,
            context: context
        )

        XCTAssertEqual(bill.status, .partiallyPaid)
        XCTAssertEqual(bill.remainingBalance, 750, accuracy: 0.01)
    }

    func testBillService_RecordPayment_RejectsOverpayment() throws {
        let bill = try BillService.shared.createBill(
            vendorName: "PG&E",
            amount: 100,
            dueDate: date(daysFromNow: 7),
            context: context
        )
        let account = makeAccount(balance: 500)

        XCTAssertThrowsError(try BillService.shared.recordPayment(
            for: bill,
            amount: 200,
            account: account,
            context: context
        )) { error in
            guard case BillServiceError.paymentExceedsBalance = error else {
                XCTFail("Expected .paymentExceedsBalance, got \(error)")
                return
            }
        }
    }

    func testBillService_RecordPayment_RejectsZeroAmount() throws {
        let bill = try BillService.shared.createBill(
            vendorName: "PG&E",
            amount: 100,
            dueDate: date(daysFromNow: 7),
            context: context
        )

        XCTAssertThrowsError(try BillService.shared.recordPayment(
            for: bill,
            amount: 0,
            context: context
        ))
    }

    // MARK: - BillService.fetchUpcomingBills

    func testBillService_FetchUpcoming_ExcludesPaidAndCancelled() throws {
        let pending = try BillService.shared.createBill(vendorName: "A", amount: 50, dueDate: date(daysFromNow: 5), context: context)
        let paid = try BillService.shared.createBill(vendorName: "B", amount: 60, dueDate: date(daysFromNow: 5), context: context)
        let cancelled = try BillService.shared.createBill(vendorName: "C", amount: 70, dueDate: date(daysFromNow: 5), context: context)
        let partial = try BillService.shared.createBill(vendorName: "D", amount: 100, dueDate: date(daysFromNow: 5), context: context)

        // Fully pay one
        try BillService.shared.recordPayment(for: paid, context: context)
        // Cancel one
        try BillService.shared.cancelBill(cancelled, context: context)
        // Partial pay
        try BillService.shared.recordPayment(for: partial, amount: 25, context: context)

        let upcoming = try BillService.shared.fetchUpcomingBills(context: context)
        let ids = Set(upcoming.map { $0.id })
        XCTAssertTrue(ids.contains(pending.id))
        XCTAssertTrue(ids.contains(partial.id), "Partially paid bills stay in upcoming")
        XCTAssertFalse(ids.contains(paid.id))
        XCTAssertFalse(ids.contains(cancelled.id))
    }

    func testBillService_FetchUpcoming_SortsUponReceiptFirst() throws {
        _ = try BillService.shared.createBill(vendorName: "PG&E", amount: 100, dueDate: date(daysFromNow: 1), context: context)
        _ = try BillService.shared.createBill(vendorName: "Plumber", amount: 200, dueDate: nil, isUponReceipt: true, context: context)
        _ = try BillService.shared.createBill(vendorName: "Comcast", amount: 80, dueDate: date(daysFromNow: 10), context: context)

        let upcoming = try BillService.shared.fetchUpcomingBills(context: context)

        XCTAssertEqual(upcoming.count, 3)
        XCTAssertEqual(upcoming[0].vendorName, "Plumber", "Upon Receipt should sort first")
        XCTAssertEqual(upcoming[1].vendorName, "PG&E", "Earlier due date next")
        XCTAssertEqual(upcoming[2].vendorName, "Comcast")
    }

    // MARK: - BillService.getTotalOutstanding

    func testBillService_GetTotalOutstanding_SumsRemainingBalances() throws {
        _ = try BillService.shared.createBill(vendorName: "A", amount: 100, dueDate: date(daysFromNow: 5), context: context)
        let partial = try BillService.shared.createBill(vendorName: "B", amount: 200, dueDate: date(daysFromNow: 5), context: context)
        let paid = try BillService.shared.createBill(vendorName: "C", amount: 300, dueDate: date(daysFromNow: 5), context: context)

        try BillService.shared.recordPayment(for: partial, amount: 50, context: context)
        try BillService.shared.recordPayment(for: paid, context: context)

        let total = try BillService.shared.getTotalOutstanding(context: context)
        // 100 (full) + 150 (200 - 50 partial) + 0 (paid) = 250
        XCTAssertEqual(total, 250, accuracy: 0.01)
    }

    // MARK: - BillService.getOverdueBills

    func testBillService_GetOverdueBills_ReturnsOnlyPastDueUnpaid() throws {
        _ = try BillService.shared.createBill(vendorName: "Future", amount: 50, dueDate: date(daysFromNow: 5), context: context)
        let overdue = try BillService.shared.createBill(vendorName: "Overdue", amount: 75, dueDate: date(daysFromNow: -3), context: context)

        let overdueBills = try BillService.shared.getOverdueBills(context: context)
        XCTAssertEqual(overdueBills.count, 1)
        XCTAssertEqual(overdueBills.first?.id, overdue.id)
    }

    // MARK: - Vendor outstandingBalance

    func testVendor_OutstandingBalance_SumsPendingBills() throws {
        let bill1 = try BillService.shared.createBill(vendorName: "PG&E", amount: 100, dueDate: date(daysFromNow: 5), context: context)
        _ = try BillService.shared.createBill(vendorName: "PG&E", amount: 200, dueDate: date(daysFromNow: 35), context: context)
        let paid = try BillService.shared.createBill(vendorName: "PG&E", amount: 300, dueDate: date(daysFromNow: -10), context: context)
        try BillService.shared.recordPayment(for: paid, context: context)

        let vendor = try XCTUnwrap(bill1.vendor)
        XCTAssertEqual(vendor.outstandingBalance, 300, accuracy: 0.01, "Should sum the two pending bills")
    }

    // MARK: - Scanner → Bill Integration (Phase 2)
    //
    // These tests exercise the same code path that `SmartReceiptScanningView.saveAndCreateBill`
    // uses when a scanned receipt is routed to a Bill. They do not drive the UI — instead they
    // replicate the exact `BillService.createBill(...)` call shape the scanner makes, including
    // image data, category-by-name resolution, and Upon Receipt handling. This catches regressions
    // in the scanner→bill contract without requiring a UI test host.

    /// Mimics the byte pattern of a JPEG header so we can verify binary data round-trips intact.
    private func fakeScannedImageData() -> Data {
        // JPEG SOI marker followed by arbitrary bytes — not a valid image, just distinctive data.
        var bytes: [UInt8] = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46]
        bytes.append(contentsOf: Array(repeating: UInt8(0xAB), count: 512))
        return Data(bytes)
    }

    func testScanner_SaveBill_PersistsScannedImageData() throws {
        let imageData = fakeScannedImageData()

        let bill = try BillService.shared.createBill(
            vendorName: "PG&E",
            amount: 142.58,
            dueDate: date(daysFromNow: 14),
            isUponReceipt: false,
            note: "Scanned bill",
            financeType: .personal,
            scannedImageData: imageData,
            context: context
        )

        XCTAssertNotNil(bill.scannedImageData, "Scanner should persist the image on the bill")
        XCTAssertEqual(bill.scannedImageData?.count, imageData.count)
        XCTAssertEqual(bill.scannedImageData, imageData, "Image bytes must round-trip exactly")
        XCTAssertEqual(bill.note, "Scanned bill")
        XCTAssertEqual(bill.vendorName, "PG&E")
        XCTAssertEqual(bill.status, .pending)
    }

    func testScanner_SaveBill_UponReceipt_NoDueDate() throws {
        // Simulates the scanner flow where the user toggles "Upon Receipt" before save.
        let bill = try BillService.shared.createBill(
            vendorName: "Smith Plumbing",
            amount: 450,
            dueDate: nil,
            isUponReceipt: true,
            note: "Scanned bill",
            financeType: .personal,
            scannedImageData: fakeScannedImageData(),
            context: context
        )

        XCTAssertTrue(bill.isUponReceipt)
        XCTAssertNil(bill.dueDate, "Upon Receipt bills must not have a stored due date")
        XCTAssertNotNil(bill.scannedImageData)
        // Upon Receipt bills sort to the very top of upcoming — verify via effectiveSortDate.
        XCTAssertEqual(bill.effectiveSortDate, .distantPast)
    }

    func testScanner_SaveBill_CategoryLookupByName_AttachesCategory() throws {
        // Scanner resolves the picked category by name via a FetchDescriptor predicate.
        // Replicate that: insert a category first, then verify createBill finds and attaches it.
        let utilities = FLO.Category(name: "Utilities", icon: "bolt.fill")
        context.insert(utilities)
        try context.save()

        let lookupName = "Utilities"
        let descriptor = FetchDescriptor<FLO.Category>(
            predicate: #Predicate<FLO.Category> { $0.name == lookupName }
        )
        let resolved = try XCTUnwrap(try context.fetch(descriptor).first,
                                     "Category lookup by name should succeed")

        let bill = try BillService.shared.createBill(
            vendorName: "PG&E",
            amount: 95.00,
            dueDate: date(daysFromNow: 7),
            note: "Scanned bill",
            financeType: .personal,
            category: resolved,
            scannedImageData: fakeScannedImageData(),
            context: context
        )

        XCTAssertEqual(bill.category?.id, utilities.id)
        XCTAssertEqual(bill.category?.name, "Utilities")
    }

    func testScanner_SaveBill_CreatesVendorIfMissing() throws {
        // Scanner extracts vendor name from OCR — may not match any existing Vendor.
        // createBill should auto-create one via findOrCreateVendor.
        let freshName = "Brand New Vendor \(UUID().uuidString.prefix(6))"

        let bill = try BillService.shared.createBill(
            vendorName: freshName,
            amount: 50,
            dueDate: date(daysFromNow: 7),
            note: "Scanned bill",
            scannedImageData: fakeScannedImageData(),
            context: context
        )

        let vendor = try XCTUnwrap(bill.vendor, "Scanner path must auto-create a Vendor")
        XCTAssertEqual(vendor.name, freshName)
        XCTAssertEqual(bill.vendorName, freshName)
    }

    func testScanner_SaveBill_PersistsAndRoundTripsViaFetch() throws {
        // End-to-end sanity: save via the scanner call shape, fetch via the upcoming query,
        // confirm the bill is retrievable with its scanned image intact.
        let imageData = fakeScannedImageData()

        _ = try BillService.shared.createBill(
            vendorName: "Comcast",
            amount: 89.99,
            dueDate: date(daysFromNow: 10),
            note: "Scanned bill",
            financeType: .personal,
            scannedImageData: imageData,
            context: context
        )
        try context.save()

        let upcoming = try BillService.shared.fetchUpcomingBills(context: context)
        let fetched = try XCTUnwrap(upcoming.first(where: { $0.vendorName == "Comcast" }),
                                    "Scanned bill should appear in upcoming")
        XCTAssertEqual(fetched.scannedImageData, imageData, "Image must survive save + fetch")
        XCTAssertEqual(fetched.amount, 89.99, accuracy: 0.01)
        XCTAssertEqual(fetched.note, "Scanned bill")
    }

    func testScanner_SaveBill_WithAccount_LinksAccount() throws {
        // Scanner flow allows picking a "Pay From" account; verify the link persists.
        let account = makeAccount(name: "Scanner Checking", balance: 2000)

        let bill = try BillService.shared.createBill(
            vendorName: "AmEx",
            amount: 300,
            dueDate: date(daysFromNow: 20),
            note: "Scanned bill",
            financeType: .business,
            account: account,
            scannedImageData: fakeScannedImageData(),
            context: context
        )

        XCTAssertEqual(bill.account?.id, account.id)
        XCTAssertEqual(bill.financeType, .business)
        // Account balance should NOT be debited on bill creation — only on payment.
        XCTAssertEqual(account.currentBalance, 2000, accuracy: 0.01,
                       "Creating a bill must not debit the account")
    }
}
