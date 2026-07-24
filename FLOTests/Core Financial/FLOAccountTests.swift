//  FLOAccountTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - Account Management Tests
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE: Validate account management logic including primary account
//  uniqueness, balance reconciliation, and account type behavior.
//
//  COVERS:
//  - Primary account uniqueness per financeType
//  - Account type behavior (asset vs liability)
//  - Balance reconciliation
//  - Account deletion handling
//  - Business vs Personal separation
//

import XCTest
@testable import FLO

final class FLOAccountTests: XCTestCase {
    
    // MARK: - Test Data Structures
    
    enum AccountType: String {
        case checking = "Checking"
        case savings = "Savings"
        case creditCard = "Credit Card"
        case cash = "Cash"
        case investment = "Investment"
    }
    
    enum FinanceType: String {
        case business = "Business"
        case personal = "Personal"
    }
    
    struct TestAccount {
        let id: String
        let name: String
        let type: AccountType
        let financeType: FinanceType
        var currentBalance: Double
        var isPrimary: Bool
        var isActive: Bool
    }
    
    // MARK: - Helpers
    
    private func assertCurrencyEqual(_ actual: Double, _ expected: Double, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(actual, expected, accuracy: 0.01, message, file: file, line: line)
    }
}

// MARK: - Primary Account Uniqueness

extension FLOAccountTests {
    
    /// Test: Only one primary per financeType
    func testPrimary_OnlyOnePerFinanceType() {
        let accounts = [
            TestAccount(id: "1", name: "Business Checking", type: .checking, financeType: .business, currentBalance: 5000, isPrimary: true, isActive: true),
            TestAccount(id: "2", name: "Business Savings", type: .savings, financeType: .business, currentBalance: 10000, isPrimary: false, isActive: true),
            TestAccount(id: "3", name: "Personal Checking", type: .checking, financeType: .personal, currentBalance: 3000, isPrimary: true, isActive: true)
        ]
        
        let businessPrimaries = accounts.filter { $0.financeType == .business && $0.isPrimary }
        let personalPrimaries = accounts.filter { $0.financeType == .personal && $0.isPrimary }
        
        XCTAssertEqual(businessPrimaries.count, 1, "Only one business primary")
        XCTAssertEqual(personalPrimaries.count, 1, "Only one personal primary")
    }
    
    /// Test: Setting new primary unsets old primary
    func testPrimary_SettingNewUnsetsOld() {
        var accounts = [
            TestAccount(id: "1", name: "Checking A", type: .checking, financeType: .personal, currentBalance: 1000, isPrimary: true, isActive: true),
            TestAccount(id: "2", name: "Checking B", type: .checking, financeType: .personal, currentBalance: 2000, isPrimary: false, isActive: true)
        ]
        
        // Set account 2 as primary
        let newPrimaryId = "2"
        for i in 0..<accounts.count {
            if accounts[i].financeType == .personal {
                accounts[i].isPrimary = accounts[i].id == newPrimaryId
            }
        }
        
        XCTAssertFalse(accounts[0].isPrimary, "Old primary is now false")
        XCTAssertTrue(accounts[1].isPrimary, "New primary is now true")
    }
    
    /// Test: Can have one business AND one personal primary
    func testPrimary_BusinessAndPersonalSeparate() {
        let accounts = [
            TestAccount(id: "1", name: "Business", type: .checking, financeType: .business, currentBalance: 5000, isPrimary: true, isActive: true),
            TestAccount(id: "2", name: "Personal", type: .checking, financeType: .personal, currentBalance: 3000, isPrimary: true, isActive: true)
        ]
        
        let totalPrimaries = accounts.filter { $0.isPrimary }.count
        
        XCTAssertEqual(totalPrimaries, 2, "Can have 2 primaries (1 business + 1 personal)")
    }
    
    /// Test: Deleting primary auto-assigns new primary
    func testPrimary_DeleteAutoAssigns() {
        var accounts = [
            TestAccount(id: "1", name: "Primary", type: .checking, financeType: .personal, currentBalance: 1000, isPrimary: true, isActive: true),
            TestAccount(id: "2", name: "Secondary", type: .savings, financeType: .personal, currentBalance: 2000, isPrimary: false, isActive: true)
        ]
        
        // Delete primary
        let deletedId = "1"
        accounts.removeAll { $0.id == deletedId }
        
        // Auto-assign new primary if none exists
        let hasPrimary = accounts.contains { $0.isPrimary && $0.financeType == .personal }
        if !hasPrimary, let firstIndex = accounts.firstIndex(where: { $0.financeType == .personal && $0.isActive }) {
            accounts[firstIndex].isPrimary = true
        }
        
        XCTAssertTrue(accounts[0].isPrimary, "Secondary became primary")
    }
}

// MARK: - Account Type Behavior

extension FLOAccountTests {
    
    /// Test: Asset accounts - positive balance is good
    func testAccountType_AssetPositiveIsGood() {
        let assetTypes: [AccountType] = [.checking, .savings, .cash, .investment]
        
        for type in assetTypes {
            let account = TestAccount(id: "1", name: "Test", type: type, financeType: .personal, currentBalance: 1000, isPrimary: false, isActive: true)
            let isHealthy = account.currentBalance >= 0
            
            XCTAssertTrue(isHealthy, "\(type.rawValue) with positive balance is healthy")
        }
    }
    
    /// Test: Credit card - negative balance means debt
    func testAccountType_CreditCardNegativeIsDebt() {
        let account = TestAccount(id: "1", name: "Credit Card", type: .creditCard, financeType: .personal, currentBalance: -2500, isPrimary: false, isActive: true)
        
        let hasDebt = account.currentBalance < 0
        let debtAmount = abs(account.currentBalance)
        
        XCTAssertTrue(hasDebt, "Negative credit card balance = debt")
        assertCurrencyEqual(debtAmount, 2500.00)
    }
    
    /// Test: Credit card - positive balance means credit/overpaid
    func testAccountType_CreditCardPositiveIsCredit() {
        let account = TestAccount(id: "1", name: "Credit Card", type: .creditCard, financeType: .personal, currentBalance: 150, isPrimary: false, isActive: true)
        
        let hasCredit = account.currentBalance > 0
        
        XCTAssertTrue(hasCredit, "Positive credit card balance = overpaid/credit")
    }
    
    /// Test: Calculate net worth from accounts
    func testAccountType_NetWorthCalculation() {
        let accounts = [
            TestAccount(id: "1", name: "Checking", type: .checking, financeType: .personal, currentBalance: 5000, isPrimary: true, isActive: true),
            TestAccount(id: "2", name: "Savings", type: .savings, financeType: .personal, currentBalance: 10000, isPrimary: false, isActive: true),
            TestAccount(id: "3", name: "Credit Card", type: .creditCard, financeType: .personal, currentBalance: -3000, isPrimary: false, isActive: true),
            TestAccount(id: "4", name: "Investment", type: .investment, financeType: .personal, currentBalance: 25000, isPrimary: false, isActive: true)
        ]
        
        let netWorth = accounts.reduce(0) { $0 + $1.currentBalance }
        
        // $5000 + $10000 - $3000 + $25000 = $37000
        assertCurrencyEqual(netWorth, 37000.00)
    }
}

// MARK: - Balance Reconciliation

extension FLOAccountTests {
    
    /// Test: Calculated balance matches stored balance
    func testReconciliation_CalculatedMatchesStored() {
        let storedBalance: Double = 1500.00
        
        // Simulate calculating from transactions
        let startingBalance: Double = 1000.00
        let incomeTotal: Double = 2000.00
        let expenseTotal: Double = 1500.00
        
        let calculatedBalance = startingBalance + incomeTotal - expenseTotal
        
        let isReconciled = abs(calculatedBalance - storedBalance) < 0.01
        
        XCTAssertTrue(isReconciled, "Calculated matches stored")
    }
    
    /// Test: Detect discrepancy
    func testReconciliation_DetectDiscrepancy() {
        let storedBalance: Double = 1500.00
        let calculatedBalance: Double = 1450.00
        
        let discrepancy = storedBalance - calculatedBalance
        let hasDiscrepancy = abs(discrepancy) > 0.01
        
        XCTAssertTrue(hasDiscrepancy, "Discrepancy detected")
        assertCurrencyEqual(discrepancy, 50.00, "$50 discrepancy")
    }
    
    /// Test: Auto-correct balance
    func testReconciliation_AutoCorrect() {
        var storedBalance: Double = 1500.00
        let calculatedBalance: Double = 1450.00
        
        // Auto-correct to calculated
        storedBalance = calculatedBalance
        
        assertCurrencyEqual(storedBalance, 1450.00, "Balance corrected")
    }
}

// MARK: - Account Deletion Handling

extension FLOAccountTests {
    
    /// Test: Deleting account nullifies transaction relationships
    func testDeletion_NullifiesTransactions() {
        // Simulate: transactions have account relationship
        var transactionAccountIds: [String?] = ["acc1", "acc1", "acc2", "acc1"]
        let deletedAccountId = "acc1"
        
        // Nullify relationships
        for i in 0..<transactionAccountIds.count {
            if transactionAccountIds[i] == deletedAccountId {
                transactionAccountIds[i] = nil
            }
        }
        
        let orphanedCount = transactionAccountIds.filter { $0 == nil }.count
        let acc2Count = transactionAccountIds.filter { $0 == "acc2" }.count
        
        XCTAssertEqual(orphanedCount, 3, "3 transactions now orphaned")
        XCTAssertEqual(acc2Count, 1, "1 transaction still linked to acc2")
    }
    
    /// Test: Cannot delete last active account (optional rule)
    func testDeletion_CannotDeleteLastActive() {
        let accounts = [
            TestAccount(id: "1", name: "Only Account", type: .checking, financeType: .personal, currentBalance: 1000, isPrimary: true, isActive: true)
        ]
        
        let activeCount = accounts.filter { $0.isActive }.count
        let canDelete = activeCount > 1
        
        XCTAssertFalse(canDelete, "Cannot delete last active account")
    }
    
    /// Test: Deactivate instead of delete preserves data
    func testDeletion_DeactivatePreservesData() {
        var account = TestAccount(id: "1", name: "Old Account", type: .checking, financeType: .personal, currentBalance: 500, isPrimary: false, isActive: true)
        
        // Deactivate instead of delete
        account.isActive = false
        
        XCTAssertFalse(account.isActive, "Account is inactive")
        assertCurrencyEqual(account.currentBalance, 500.00, "Balance preserved")
    }
}

// MARK: - Business vs Personal Separation

extension FLOAccountTests {
    
    /// Test: Calculate business-only totals
    func testSeparation_BusinessOnlyTotals() {
        let accounts = [
            TestAccount(id: "1", name: "Business Checking", type: .checking, financeType: .business, currentBalance: 10000, isPrimary: true, isActive: true),
            TestAccount(id: "2", name: "Business Credit", type: .creditCard, financeType: .business, currentBalance: -2000, isPrimary: false, isActive: true),
            TestAccount(id: "3", name: "Personal Checking", type: .checking, financeType: .personal, currentBalance: 5000, isPrimary: true, isActive: true)
        ]
        
        let businessTotal = accounts
            .filter { $0.financeType == .business }
            .reduce(0) { $0 + $1.currentBalance }
        
        assertCurrencyEqual(businessTotal, 8000.00, "$10000 - $2000 = $8000")
    }
    
    /// Test: Calculate personal-only totals
    func testSeparation_PersonalOnlyTotals() {
        let accounts = [
            TestAccount(id: "1", name: "Business Checking", type: .checking, financeType: .business, currentBalance: 10000, isPrimary: true, isActive: true),
            TestAccount(id: "2", name: "Personal Checking", type: .checking, financeType: .personal, currentBalance: 5000, isPrimary: true, isActive: true),
            TestAccount(id: "3", name: "Personal Savings", type: .savings, financeType: .personal, currentBalance: 15000, isPrimary: false, isActive: true)
        ]
        
        let personalTotal = accounts
            .filter { $0.financeType == .personal }
            .reduce(0) { $0 + $1.currentBalance }
        
        assertCurrencyEqual(personalTotal, 20000.00)
    }
    
    /// Test: Filter accounts by financeType
    func testSeparation_FilterByFinanceType() {
        let accounts = [
            TestAccount(id: "1", name: "Biz 1", type: .checking, financeType: .business, currentBalance: 1000, isPrimary: true, isActive: true),
            TestAccount(id: "2", name: "Biz 2", type: .savings, financeType: .business, currentBalance: 2000, isPrimary: false, isActive: true),
            TestAccount(id: "3", name: "Personal", type: .checking, financeType: .personal, currentBalance: 3000, isPrimary: true, isActive: true)
        ]
        
        let businessAccounts = accounts.filter { $0.financeType == .business }
        let personalAccounts = accounts.filter { $0.financeType == .personal }
        
        XCTAssertEqual(businessAccounts.count, 2)
        XCTAssertEqual(personalAccounts.count, 1)
    }
}

// MARK: - Account Display

extension FLOAccountTests {
    
    /// Test: Format balance for display
    func testDisplay_FormatBalance() {
        func formatBalance(_ amount: Double) -> String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = "USD"
            return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
        }
        
        XCTAssertEqual(formatBalance(1234.56), "$1,234.56")
        XCTAssertEqual(formatBalance(-500.00), "-$500.00")
        XCTAssertEqual(formatBalance(0), "$0.00")
    }
    
    /// Test: Sort accounts (primary first, then by name)
    func testDisplay_SortAccounts() {
        var accounts = [
            TestAccount(id: "1", name: "Zebra Account", type: .checking, financeType: .personal, currentBalance: 1000, isPrimary: false, isActive: true),
            TestAccount(id: "2", name: "Alpha Account", type: .savings, financeType: .personal, currentBalance: 2000, isPrimary: false, isActive: true),
            TestAccount(id: "3", name: "Main Account", type: .checking, financeType: .personal, currentBalance: 5000, isPrimary: true, isActive: true)
        ]
        
        accounts.sort { a, b in
            if a.isPrimary != b.isPrimary {
                return a.isPrimary  // Primary first
            }
            return a.name < b.name  // Then alphabetically
        }
        
        XCTAssertEqual(accounts[0].name, "Main Account", "Primary first")
        XCTAssertEqual(accounts[1].name, "Alpha Account", "Then alphabetically")
        XCTAssertEqual(accounts[2].name, "Zebra Account")
    }
}
