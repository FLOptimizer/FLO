//  BillService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Bill CRUD, Vendor lookup, Mark Paid flow
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Service layer for the Bills feature. Mirrors InvoiceService conventions:
//  @MainActor, @Observable, singleton, throwing methods that take ModelContext.
//
//  CHANGES v1.0:
//  ✅ Initial bill service
//  ✅ CRUD for Bill, find-or-create for Vendor
//  ✅ recordPayment wrapper that saves and rolls back on failure
//  ✅ Upcoming/overdue/outstanding queries

import Foundation
import SwiftData

// MARK: - Custom Error Types

enum BillServiceError: LocalizedError {
    case saveFailed(String)
    case fetchFailed(String)
    case invalidData(String)
    case billNotFound
    case vendorRequired
    case paymentExceedsBalance(remaining: Double, attempted: Double)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let details):
            return "Failed to save bill: \(details)"
        case .fetchFailed(let details):
            return "Failed to fetch bills: \(details)"
        case .invalidData(let details):
            return "Invalid bill data: \(details)"
        case .billNotFound:
            return "Bill not found"
        case .vendorRequired:
            return "A vendor name is required"
        case .paymentExceedsBalance(let remaining, let attempted):
            return "Payment of \(attempted.formatted(.currency(code: "USD"))) exceeds remaining balance of \(remaining.formatted(.currency(code: "USD")))"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .saveFailed:
            return "Please try again. If the problem persists, restart the app."
        case .fetchFailed:
            return "Please try again or restart the app."
        case .invalidData:
            return "Please verify all required fields are filled correctly."
        case .billNotFound:
            return "The bill may have been deleted. Please refresh the list."
        case .vendorRequired:
            return "Please enter a vendor name before saving."
        case .paymentExceedsBalance:
            return "Reduce the payment amount to the remaining balance or below."
        }
    }
}

// MARK: - Service Class

@MainActor
@Observable
class BillService {
    static let shared = BillService()

    private init() {}

    // MARK: - Bill Creation

    /// Create a new bill. The vendor is matched by name (case-insensitive); a new
    /// `Vendor` is created if no match exists.
    @discardableResult
    func createBill(
        vendorName: String,
        amount: Double,
        dueDate: Date?,
        isUponReceipt: Bool = false,
        note: String = "",
        financeType: Transaction.FinanceType = .personal,
        category: Category? = nil,
        account: Account? = nil,
        scannedImageData: Data? = nil,
        context: ModelContext
    ) throws -> Bill {
        let trimmed = vendorName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw BillServiceError.vendorRequired
        }
        guard amount > 0 else {
            throw BillServiceError.invalidData("Amount must be greater than zero.")
        }
        guard isUponReceipt || dueDate != nil else {
            throw BillServiceError.invalidData("A bill must have a due date or be marked Upon Receipt.")
        }

        let vendor = try findOrCreateVendor(name: trimmed, context: context)

        let bill = Bill(
            vendorName: trimmed,
            amount: amount,
            note: note,
            dueDate: dueDate,
            isUponReceipt: isUponReceipt,
            status: .pending,
            financeType: financeType,
            vendor: vendor,
            category: category ?? vendor.defaultCategory,
            account: account ?? vendor.defaultAccount,
            scannedImageData: scannedImageData
        )

        context.insert(bill)
        vendor.touch()

        do {
            try context.save()
            print("✅ Bill created: \(trimmed) — \(bill.formattedAmount)")
            return bill
        } catch {
            context.delete(bill)
            throw BillServiceError.saveFailed(error.localizedDescription)
        }
    }

    // MARK: - Bill Updates

    /// Update editable fields on a bill. Pass nil for fields you don't want to change.
    func updateBill(
        _ bill: Bill,
        vendorName: String? = nil,
        amount: Double? = nil,
        dueDate: Date?? = nil,
        isUponReceipt: Bool? = nil,
        note: String? = nil,
        financeType: Transaction.FinanceType? = nil,
        category: Category?? = nil,
        account: Account?? = nil,
        context: ModelContext
    ) throws {
        // Snapshot for rollback
        let previousVendorName = bill.vendorName
        let previousAmount = bill.amount
        let previousDueDate = bill.dueDate
        let previousIsUponReceipt = bill.isUponReceipt
        let previousNote = bill.note
        let previousFinanceType = bill.financeType
        let previousCategory = bill.category
        let previousAccount = bill.account
        let previousVendor = bill.vendor

        if let vendorName {
            let trimmed = vendorName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw BillServiceError.vendorRequired }
            bill.vendorName = trimmed
            // Re-link to a vendor with the new name
            bill.vendor = try findOrCreateVendor(name: trimmed, context: context)
        }
        if let amount {
            guard amount > 0 else {
                throw BillServiceError.invalidData("Amount must be greater than zero.")
            }
            bill.amount = amount
        }
        if let isUponReceipt {
            bill.isUponReceipt = isUponReceipt
            if isUponReceipt {
                bill.dueDate = nil
            }
        }
        if case .some(let newDueDate) = dueDate, !bill.isUponReceipt {
            bill.dueDate = newDueDate
        }
        if let note { bill.note = note }
        if let financeType { bill.financeType = financeType }
        if case .some(let newCategory) = category { bill.category = newCategory }
        if case .some(let newAccount) = account { bill.account = newAccount }

        bill.touch()

        do {
            try context.save()
        } catch {
            bill.vendorName = previousVendorName
            bill.amount = previousAmount
            bill.dueDate = previousDueDate
            bill.isUponReceipt = previousIsUponReceipt
            bill.note = previousNote
            bill.financeType = previousFinanceType
            bill.category = previousCategory
            bill.account = previousAccount
            bill.vendor = previousVendor
            throw BillServiceError.saveFailed(error.localizedDescription)
        }
    }

    // MARK: - Payment Recording

    /// Record a payment against a bill. Wraps `Bill.recordPayment` with save + rollback.
    /// - Returns: The created `BillPayment` and posted `Transaction`.
    @discardableResult
    func recordPayment(
        for bill: Bill,
        amount: Double? = nil,
        date: Date = Date(),
        paymentMethod: PaymentMethod = .bankTransfer,
        account: Account? = nil,
        notes: String = "",
        context: ModelContext
    ) throws -> (payment: BillPayment, transaction: Transaction) {
        let resolvedAmount = amount ?? bill.remainingBalance
        guard resolvedAmount > 0 else {
            throw BillServiceError.invalidData("Payment amount must be greater than zero.")
        }
        // Allow a tiny rounding tolerance over the remaining balance
        if resolvedAmount > bill.remainingBalance + 0.01 {
            throw BillServiceError.paymentExceedsBalance(
                remaining: bill.remainingBalance,
                attempted: resolvedAmount
            )
        }

        let result = bill.recordPayment(
            amount: resolvedAmount,
            date: date,
            paymentMethod: paymentMethod,
            account: account,
            notes: notes,
            in: context
        )

        do {
            try context.save()
            print("✅ Bill payment recorded: \(bill.vendorName) — \(result.payment.formattedAmount)")
            return result
        } catch {
            // Best-effort rollback: remove the payment + transaction we just created
            bill.payments?.removeAll { $0.id == result.payment.id }
            context.delete(result.payment)
            context.delete(result.transaction)
            // Restore the account balance debit
            result.transaction.account?.recordTransaction(amount: result.payment.amount, isIncome: true)
            bill.updatePaymentStatus()
            throw BillServiceError.saveFailed(error.localizedDescription)
        }
    }

    // MARK: - Status Changes

    func cancelBill(_ bill: Bill, context: ModelContext) throws {
        let previousStatus = bill.status
        bill.cancel()

        do {
            try context.save()
        } catch {
            bill.status = previousStatus
            throw BillServiceError.saveFailed(error.localizedDescription)
        }
    }

    func reactivateBill(_ bill: Bill, context: ModelContext) throws {
        let previousStatus = bill.status
        bill.reactivate()

        do {
            try context.save()
        } catch {
            bill.status = previousStatus
            throw BillServiceError.saveFailed(error.localizedDescription)
        }
    }

    func deleteBill(_ bill: Bill, context: ModelContext) throws {
        context.delete(bill)
        do {
            try context.save()
        } catch {
            throw BillServiceError.saveFailed(error.localizedDescription)
        }
    }

    // MARK: - Fetching

    /// Bills currently in the Upcoming list: pending + partially paid.
    /// Sorted with Upon Receipt first, then by due date ascending.
    func fetchUpcomingBills(context: ModelContext) throws -> [Bill] {
        // SwiftData enum-equality predicates throw at runtime in the current SDK,
        // so we fetch all bills and filter + sort in-memory. The Upcoming list is
        // expected to be small (tens of items), so this is fine.
        let descriptor = FetchDescriptor<Bill>(
            sortBy: [SortDescriptor(\.createdDate, order: .reverse)]
        )
        do {
            let allBills = try context.fetch(descriptor)
            let bills = allBills.filter { $0.status == .pending || $0.status == .partiallyPaid }
            return bills.sorted { lhs, rhs in
                if lhs.isUponReceipt != rhs.isUponReceipt {
                    return lhs.isUponReceipt
                }
                return lhs.effectiveSortDate < rhs.effectiveSortDate
            }
        } catch {
            throw BillServiceError.fetchFailed(error.localizedDescription)
        }
    }

    func fetchAllBills(context: ModelContext) throws -> [Bill] {
        let descriptor = FetchDescriptor<Bill>(
            sortBy: [SortDescriptor(\.createdDate, order: .reverse)]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            throw BillServiceError.fetchFailed(error.localizedDescription)
        }
    }

    func fetchBills(for vendor: Vendor, context: ModelContext) throws -> [Bill] {
        let vendorId = vendor.id
        let descriptor = FetchDescriptor<Bill>(
            predicate: #Predicate<Bill> { bill in
                bill.vendor?.id == vendorId
            },
            sortBy: [SortDescriptor(\.createdDate, order: .reverse)]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            throw BillServiceError.fetchFailed(error.localizedDescription)
        }
    }

    // MARK: - Reporting

    /// Sum of remaining balance across all pending and partially-paid bills.
    func getTotalOutstanding(context: ModelContext) throws -> Double {
        let bills = try fetchUpcomingBills(context: context)
        return bills.reduce(0) { $0 + $1.remainingBalance }
    }

    /// Bills that are computed-overdue (past due date and not fully paid).
    func getOverdueBills(context: ModelContext) throws -> [Bill] {
        let upcoming = try fetchUpcomingBills(context: context)
        return upcoming.filter { $0.isOverdue }
    }

    // MARK: - Vendor Lookup / Create

    /// Find an existing vendor by case-insensitive name match, or create a new one.
    func findOrCreateVendor(name: String, context: ModelContext) throws -> Vendor {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw BillServiceError.vendorRequired
        }

        // Case-insensitive lookup. SwiftData predicates support `localizedStandardContains`
        // but not direct case-insensitive equality, so we fetch candidates and filter.
        let descriptor = FetchDescriptor<Vendor>()
        let allVendors: [Vendor]
        do {
            allVendors = try context.fetch(descriptor)
        } catch {
            throw BillServiceError.fetchFailed(error.localizedDescription)
        }

        if let existing = allVendors.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return existing
        }

        let newVendor = Vendor(name: trimmed)
        context.insert(newVendor)
        return newVendor
    }

    func fetchAllVendors(context: ModelContext) throws -> [Vendor] {
        let descriptor = FetchDescriptor<Vendor>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            throw BillServiceError.fetchFailed(error.localizedDescription)
        }
    }
}
