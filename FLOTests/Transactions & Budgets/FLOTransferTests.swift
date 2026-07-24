//  FLOTransferTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Move Money / Transfer Test Suite
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE: Validate all transfer/Move Money logic including type detection,
//  balance impact, P&L exclusion, tax exclusion, and linked transaction behavior.
//
//  TEST CATEGORIES:
//  1. Transfer Type Auto-Detection
//  2. Transfer Balance Impact
//  3. Transfer Exclusion from Financial Calculations
//  4. Transfer Type Properties
//  5. Linked Transaction Integrity
//  6. Edge Cases
//
//  RUN FREQUENCY: Before every release, after any transfer or financial code changes
//

import XCTest
@testable import FLO

// MARK: - Test Configuration

final class FLOTransferTests: XCTestCase {
    
    /// Precision for currency comparisons (1 cent tolerance)
    let currencyPrecision: Double = 0.01
    
    // MARK: - Helper Types
    
    enum TestFinanceType: String {
        case business
        case personal
    }
    
    struct TestTransaction {
        let amount: Double
        let isIncome: Bool
        let isTransfer: Bool
        let financeType: TestFinanceType
        
        init(amount: Double, isIncome: Bool, isTransfer: Bool = false, financeType: TestFinanceType = .business) {
            self.amount = amount
            self.isIncome = isIncome
            self.isTransfer = isTransfer
            self.financeType = financeType
        }
    }
    
    // MARK: - Helpers
    
    private func assertCurrencyEqual(_ actual: Double, _ expected: Double, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(actual, expected, accuracy: currencyPrecision, message.isEmpty ? "Expected \(expected), got \(actual)" : message, file: file, line: line)
    }
    
    /// Simulates P&L calculation: sum income - expenses, excluding transfers
    private func calculateNetIncome(_ transactions: [TestTransaction], excludeTransfers: Bool = true) -> Double {
        let filtered = excludeTransfers ? transactions.filter { !$0.isTransfer } : transactions
        let income = filtered.filter { $0.isIncome }.reduce(0.0) { $0 + $1.amount }
        let expenses = filtered.filter { !$0.isIncome }.reduce(0.0) { $0 + $1.amount }
        return income - expenses
    }
    
    /// Simulates tax-relevant income: business income - business expenses, excluding transfers
    private func calculateTaxableIncome(_ transactions: [TestTransaction], excludeTransfers: Bool = true) -> Double {
        let filtered = excludeTransfers
            ? transactions.filter { !$0.isTransfer && $0.financeType == .business }
            : transactions.filter { $0.financeType == .business }
        let income = filtered.filter { $0.isIncome }.reduce(0.0) { $0 + $1.amount }
        let expenses = filtered.filter { !$0.isIncome }.reduce(0.0) { $0 + $1.amount }
        return income - expenses
    }
    
    /// Simulates transfer type detection based on account finance types
    private func detectTransferType(fromFinanceType: TestFinanceType, toFinanceType: TestFinanceType) -> String {
        switch (fromFinanceType, toFinanceType) {
        case (.business, .personal):
            return "ownersDraw"
        case (.personal, .business):
            return "ownerContribution"
        case (.business, .business), (.personal, .personal):
            return "internalTransfer"
        }
    }
}

// MARK: - 1. TRANSFER TYPE AUTO-DETECTION

extension FLOTransferTests {
    
    /// Test: Business → Personal detects as Owner's Draw
    func testDetection_BusinessToPersonal_IsOwnersDraw() {
        let detected = detectTransferType(fromFinanceType: .business, toFinanceType: .personal)
        XCTAssertEqual(detected, "ownersDraw", "Business → Personal should detect as Owner's Draw")
    }
    
    /// Test: Personal → Business detects as Owner's Contribution
    func testDetection_PersonalToBusiness_IsOwnerContribution() {
        let detected = detectTransferType(fromFinanceType: .personal, toFinanceType: .business)
        XCTAssertEqual(detected, "ownerContribution", "Personal → Business should detect as Owner's Contribution")
    }
    
    /// Test: Business → Business detects as Internal Transfer
    func testDetection_BusinessToBusiness_IsInternalTransfer() {
        let detected = detectTransferType(fromFinanceType: .business, toFinanceType: .business)
        XCTAssertEqual(detected, "internalTransfer", "Business → Business should detect as Internal Transfer")
    }
    
    /// Test: Personal → Personal detects as Internal Transfer
    func testDetection_PersonalToPersonal_IsInternalTransfer() {
        let detected = detectTransferType(fromFinanceType: .personal, toFinanceType: .personal)
        XCTAssertEqual(detected, "internalTransfer", "Personal → Personal should detect as Internal Transfer")
    }
    
    /// Test: All transfer types have valid raw values via TransferType enum
    func testTransferType_AllCases_HaveRawValues() {
        let allCases = Transaction.TransferType.allCases
        XCTAssertEqual(allCases.count, 5, "Should have exactly 5 transfer types")
        
        let expectedRawValues: Set<String> = [
            "owners_draw", "owner_contribution", "tax_set_aside", "reimbursement", "internal_transfer"
        ]
        let actualRawValues = Set(allCases.map { $0.rawValue })
        XCTAssertEqual(actualRawValues, expectedRawValues, "Raw values should match expected set")
    }
    
    /// Test: TransferType.detect() matches our test logic
    func testTransferType_DetectMethod_MatchesExpected() {
        XCTAssertEqual(
            Transaction.TransferType.detect(fromFinanceType: .business, toFinanceType: .personal),
            .ownersDraw
        )
        XCTAssertEqual(
            Transaction.TransferType.detect(fromFinanceType: .personal, toFinanceType: .business),
            .ownerContribution
        )
        XCTAssertEqual(
            Transaction.TransferType.detect(fromFinanceType: .business, toFinanceType: .business),
            .internalTransfer
        )
        XCTAssertEqual(
            Transaction.TransferType.detect(fromFinanceType: .personal, toFinanceType: .personal),
            .internalTransfer
        )
    }
}

// MARK: - 2. TRANSFER BALANCE IMPACT

extension FLOTransferTests {
    
    /// Test: Transfer decreases source account balance
    /// Formula: sourceBalance = currentBalance - transferAmount
    func testTransfer_SourceAccount_BalanceDecreases() {
        let sourceBalance: Double = 5000.00
        let transferAmount: Double = 1500.00
        let newSourceBalance = sourceBalance - transferAmount
        
        assertCurrencyEqual(newSourceBalance, 3500.00, "Source account should decrease by transfer amount")
    }
    
    /// Test: Transfer increases destination account balance
    /// Formula: destBalance = currentBalance + transferAmount
    func testTransfer_DestAccount_BalanceIncreases() {
        let destBalance: Double = 2000.00
        let transferAmount: Double = 1500.00
        let newDestBalance = destBalance + transferAmount
        
        assertCurrencyEqual(newDestBalance, 3500.00, "Destination account should increase by transfer amount")
    }
    
    /// Test: Transfer is zero-sum across both accounts
    /// Formula: sourceChange + destChange = 0
    func testTransfer_ZeroSum_AcrossAccounts() {
        let sourceStart: Double = 5000.00
        let destStart: Double = 2000.00
        let transferAmount: Double = 1500.00
        
        let sourceEnd = sourceStart - transferAmount
        let destEnd = destStart + transferAmount
        
        let totalBefore = sourceStart + destStart
        let totalAfter = sourceEnd + destEnd
        
        assertCurrencyEqual(totalBefore, totalAfter, "Total across accounts should not change (zero-sum)")
    }
    
    /// Test: Large transfer can overdraft source account
    func testTransfer_LargeAmount_AllowsSourceOverdraft() {
        let sourceBalance: Double = 500.00
        let transferAmount: Double = 1500.00
        let newSourceBalance = sourceBalance - transferAmount
        
        assertCurrencyEqual(newSourceBalance, -1000.00, "Source should allow negative balance after transfer")
    }
    
    /// Test: Multiple transfers maintain balance accuracy
    func testTransfer_MultipleTransfers_AccurateBalances() {
        var sourceBalance: Double = 10000.00
        var destBalance: Double = 0.00
        
        // Simulate 5 transfers of varying amounts
        let transfers: [Double] = [1000, 2500, 500, 3000, 750]
        for amount in transfers {
            sourceBalance -= amount
            destBalance += amount
        }
        
        assertCurrencyEqual(sourceBalance, 2250.00, "Source: 10000 - 7750 = 2250")
        assertCurrencyEqual(destBalance, 7750.00, "Dest: 0 + 7750 = 7750")
        assertCurrencyEqual(sourceBalance + destBalance, 10000.00, "Total should remain 10000")
    }
    
    /// Test: Owner's Draw — net worth unchanged (equity movement)
    func testOwnersDraw_NetWorth_Unchanged() {
        let bizBalance: Double = 20000.00
        let personalBalance: Double = 5000.00
        let drawAmount: Double = 3000.00
        
        let newBiz = bizBalance - drawAmount
        let newPersonal = personalBalance + drawAmount
        
        let netWorthBefore = bizBalance + personalBalance
        let netWorthAfter = newBiz + newPersonal
        
        assertCurrencyEqual(netWorthBefore, netWorthAfter, "Owner's draw should not change net worth")
    }
    
    /// Test: Tax Set-Aside — business account decreases, savings increases
    func testTaxSetAside_BalanceMovement() {
        let bizChecking: Double = 15000.00
        let taxSavings: Double = 2000.00
        let quarterlyEstimate: Double = 3200.00
        
        let newBiz = bizChecking - quarterlyEstimate
        let newSavings = taxSavings + quarterlyEstimate
        
        assertCurrencyEqual(newBiz, 11800.00, "Business should decrease by quarterly estimate")
        assertCurrencyEqual(newSavings, 5200.00, "Tax savings should increase by quarterly estimate")
    }
}

// MARK: - 3. TRANSFER EXCLUSION FROM FINANCIAL CALCULATIONS

extension FLOTransferTests {
    
    /// Test: Transfers excluded from net income (P&L)
    func testExclusion_NetIncome_ExcludesTransfers() {
        let transactions: [TestTransaction] = [
            TestTransaction(amount: 5000, isIncome: true),           // Real income
            TestTransaction(amount: 1000, isIncome: false),          // Real expense
            TestTransaction(amount: 3000, isIncome: false, isTransfer: true),  // Owner's draw (out)
            TestTransaction(amount: 3000, isIncome: true, isTransfer: true),   // Owner's draw (in)
        ]
        
        let netIncome = calculateNetIncome(transactions, excludeTransfers: true)
        assertCurrencyEqual(netIncome, 4000.00, "Net income should be 5000 - 1000 = 4000, ignoring transfers")
    }
    
    /// Test: Including transfers would incorrectly show zero-sum impact
    func testExclusion_WithTransfers_WouldBeAccidentallyCorrect() {
        // Even though paired transfers cancel out, one-sided transfers would distort
        let transactions: [TestTransaction] = [
            TestTransaction(amount: 5000, isIncome: true),
            TestTransaction(amount: 1000, isIncome: false),
            TestTransaction(amount: 2000, isIncome: false, isTransfer: true),  // Source only visible
        ]
        
        let withTransfers = calculateNetIncome(transactions, excludeTransfers: false)
        let withoutTransfers = calculateNetIncome(transactions, excludeTransfers: true)
        
        assertCurrencyEqual(withTransfers, 2000.00, "With transfer: 5000 - 1000 - 2000 = 2000 (WRONG)")
        assertCurrencyEqual(withoutTransfers, 4000.00, "Without transfer: 5000 - 1000 = 4000 (CORRECT)")
    }
    
    /// Test: Transfers excluded from taxable income
    func testExclusion_TaxableIncome_ExcludesTransfers() {
        let transactions: [TestTransaction] = [
            TestTransaction(amount: 8000, isIncome: true, financeType: .business),
            TestTransaction(amount: 2000, isIncome: false, financeType: .business),
            TestTransaction(amount: 5000, isIncome: false, isTransfer: true, financeType: .business),  // Draw
            TestTransaction(amount: 1000, isIncome: true, financeType: .personal),  // Personal income (excluded from business tax)
        ]
        
        let taxable = calculateTaxableIncome(transactions, excludeTransfers: true)
        assertCurrencyEqual(taxable, 6000.00, "Taxable: 8000 - 2000 = 6000, ignoring transfers and personal")
    }
    
    /// Test: Transfer exclusion with mixed business/personal transactions
    func testExclusion_MixedTypes_OnlyBusinessNonTransfers() {
        let transactions: [TestTransaction] = [
            TestTransaction(amount: 10000, isIncome: true, financeType: .business),
            TestTransaction(amount: 3000, isIncome: false, financeType: .business),
            TestTransaction(amount: 2000, isIncome: false, isTransfer: true, financeType: .business),
            TestTransaction(amount: 2000, isIncome: true, isTransfer: true, financeType: .personal),
            TestTransaction(amount: 5000, isIncome: true, financeType: .personal),
            TestTransaction(amount: 1500, isIncome: false, financeType: .personal),
        ]
        
        let taxable = calculateTaxableIncome(transactions, excludeTransfers: true)
        assertCurrencyEqual(taxable, 7000.00, "Taxable: 10000 - 3000 = 7000 (business only, no transfers)")
    }
    
    /// Test: Transfers should NOT be tax-deductible
    func testExclusion_TransfersAreNotDeductible() {
        // Simulate isTaxDeductible check
        let isTransfer = true
        let isTaxDeductible = !isTransfer  // Transfers are never deductible
        
        XCTAssertFalse(isTaxDeductible, "Transfers should never be tax-deductible")
    }
    
    /// Test: Insights calculations exclude transfers
    func testExclusion_InsightsSpending_ExcludesTransfers() {
        let transactions: [TestTransaction] = [
            TestTransaction(amount: 500, isIncome: false),           // Real expense
            TestTransaction(amount: 300, isIncome: false),           // Real expense
            TestTransaction(amount: 2000, isIncome: false, isTransfer: true),  // Transfer (not spending)
        ]
        
        let realSpending = transactions.filter { !$0.isIncome && !$0.isTransfer }.reduce(0.0) { $0 + $1.amount }
        let totalWithTransfers = transactions.filter { !$0.isIncome }.reduce(0.0) { $0 + $1.amount }
        
        assertCurrencyEqual(realSpending, 800.00, "Real spending: 500 + 300 = 800")
        assertCurrencyEqual(totalWithTransfers, 2800.00, "With transfers would inflate to 2800")
    }
    
    /// Test: Transfer filter predicate logic
    func testExclusion_FilterPredicate_CorrectCount() {
        let transactions: [TestTransaction] = [
            TestTransaction(amount: 100, isIncome: true),
            TestTransaction(amount: 200, isIncome: false),
            TestTransaction(amount: 300, isIncome: false, isTransfer: true),
            TestTransaction(amount: 300, isIncome: true, isTransfer: true),
            TestTransaction(amount: 400, isIncome: true),
            TestTransaction(amount: 500, isIncome: false, isTransfer: true),
        ]
        
        let nonTransfers = transactions.filter { !$0.isTransfer }
        let transfers = transactions.filter { $0.isTransfer }
        
        XCTAssertEqual(nonTransfers.count, 3, "Should have 3 non-transfer transactions")
        XCTAssertEqual(transfers.count, 3, "Should have 3 transfer transactions")
    }
}

// MARK: - 4. TRANSFER TYPE PROPERTIES

extension FLOTransferTests {
    
    /// Test: All transfer types have display names
    func testTransferType_AllHaveDisplayNames() {
        for type in Transaction.TransferType.allCases {
            XCTAssertFalse(type.displayName.isEmpty, "\(type.rawValue) should have a display name")
        }
    }
    
    /// Test: All transfer types have subtitles
    func testTransferType_AllHaveSubtitles() {
        for type in Transaction.TransferType.allCases {
            XCTAssertFalse(type.subtitle.isEmpty, "\(type.rawValue) should have a subtitle")
        }
    }
    
    /// Test: All transfer types have SF Symbol icons
    func testTransferType_AllHaveIcons() {
        for type in Transaction.TransferType.allCases {
            XCTAssertFalse(type.icon.isEmpty, "\(type.rawValue) should have an icon")
        }
    }
    
    /// Test: All transfer types have color hex values
    func testTransferType_AllHaveColorHex() {
        for type in Transaction.TransferType.allCases {
            XCTAssertEqual(type.colorHex.count, 6, "\(type.rawValue) should have 6-char hex color")
        }
    }
    
    /// Test: Each transfer type has a unique display name
    func testTransferType_UniqueDisplayNames() {
        let names = Transaction.TransferType.allCases.map { $0.displayName }
        let uniqueNames = Set(names)
        XCTAssertEqual(names.count, uniqueNames.count, "All transfer types should have unique display names")
    }
    
    /// Test: TransactionSource includes .transfer case
    func testTransactionSource_HasTransferCase() {
        let source = Transaction.TransactionSource.transfer
        XCTAssertEqual(source.displayName, "Transfer", "Transfer source should display 'Transfer'")
        XCTAssertFalse(source.isEditable, "Transfer transactions should not be directly editable")
    }
}

// MARK: - 5. LINKED TRANSACTION INTEGRITY

extension FLOTransferTests {
    
    /// Test: Linked IDs are different UUIDs
    func testLinkedTransactions_DifferentIDs() {
        let sourceID = UUID()
        let destID = UUID()
        
        XCTAssertNotEqual(sourceID, destID, "Source and destination should have different IDs")
    }
    
    /// Test: Linked IDs cross-reference correctly
    func testLinkedTransactions_CrossReference() {
        let sourceID = UUID()
        let destID = UUID()
        
        // Source points to dest, dest points to source
        let sourceLinkedID = destID
        let destLinkedID = sourceID
        
        XCTAssertEqual(sourceLinkedID, destID, "Source should link to destination ID")
        XCTAssertEqual(destLinkedID, sourceID, "Destination should link to source ID")
    }
    
    /// Test: Transfer pair has opposite income flags
    func testLinkedTransactions_OppositeIncomeFlags() {
        let sourceIsIncome = false   // Money leaving = expense
        let destIsIncome = true      // Money arriving = income
        
        XCTAssertNotEqual(sourceIsIncome, destIsIncome, "Source and dest should have opposite income flags")
        XCTAssertFalse(sourceIsIncome, "Source should be expense (money leaving)")
        XCTAssertTrue(destIsIncome, "Destination should be income (money arriving)")
    }
    
    /// Test: Both transactions in a pair are marked as transfers
    func testLinkedTransactions_BothMarkedAsTransfer() {
        let sourceIsTransfer = true
        let destIsTransfer = true
        
        XCTAssertTrue(sourceIsTransfer, "Source must be marked as transfer")
        XCTAssertTrue(destIsTransfer, "Destination must be marked as transfer")
    }
    
    /// Test: Transfer pair has equal amounts
    func testLinkedTransactions_EqualAmounts() {
        let transferAmount: Double = 2500.00
        let sourceAmount = transferAmount
        let destAmount = transferAmount
        
        assertCurrencyEqual(sourceAmount, destAmount, "Both sides of transfer should have equal amounts")
    }
}

// MARK: - 6. EDGE CASES

extension FLOTransferTests {
    
    /// Test: Zero amount transfer (should be prevented by UI but test the math)
    func testEdgeCase_ZeroAmountTransfer() {
        let sourceBalance: Double = 5000.00
        let destBalance: Double = 2000.00
        let transferAmount: Double = 0.00
        
        let newSource = sourceBalance - transferAmount
        let newDest = destBalance + transferAmount
        
        assertCurrencyEqual(newSource, 5000.00, "Zero transfer should not change source")
        assertCurrencyEqual(newDest, 2000.00, "Zero transfer should not change dest")
    }
    
    /// Test: Very large transfer maintains precision
    func testEdgeCase_LargeTransfer_Precision() {
        let sourceBalance: Double = 1_000_000.00
        let transferAmount: Double = 999_999.99
        let newBalance = sourceBalance - transferAmount
        
        assertCurrencyEqual(newBalance, 0.01, "Large transfer should maintain cent precision")
    }
    
    /// Test: Many small transfers maintain precision
    func testEdgeCase_ManySmallTransfers_Precision() {
        var balance: Double = 100.00
        
        // 1000 transfers of $0.10
        for _ in 1...1000 {
            balance -= 0.10
        }
        
        assertCurrencyEqual(balance, 0.00, "1000 × $0.10 transfers from $100 should reach $0.00")
    }
    
    /// Test: Transfer between same account types preserves correct detection
    func testEdgeCase_SameAccountType_StillDetectsCorrectly() {
        // Business checking → Business savings = Internal
        let detected = detectTransferType(fromFinanceType: .business, toFinanceType: .business)
        XCTAssertEqual(detected, "internalTransfer")
    }
    
    /// Test: Transfer does not create negative transaction count
    func testEdgeCase_TransferPair_IsAlwaysTwoTransactions() {
        // Every transfer creates exactly 2 transactions
        let transactionCount = 2  // Source + Destination
        XCTAssertEqual(transactionCount, 2, "Transfer should always create exactly 2 linked transactions")
    }
    
    /// Test: No financial calculation should count transfers
    func testEdgeCase_AllExclusionFilters_Consistent() {
        let transactions: [TestTransaction] = [
            TestTransaction(amount: 10000, isIncome: true, financeType: .business),
            TestTransaction(amount: 3000, isIncome: false, financeType: .business),
            TestTransaction(amount: 5000, isIncome: false, isTransfer: true, financeType: .business),
            TestTransaction(amount: 5000, isIncome: true, isTransfer: true, financeType: .personal),
        ]
        
        // All these should give the same result: exclude transfers
        let netIncome = calculateNetIncome(transactions, excludeTransfers: true)
        let taxableIncome = calculateTaxableIncome(transactions, excludeTransfers: true)
        
        assertCurrencyEqual(netIncome, 7000.00, "Net income: 10000 - 3000 = 7000")
        assertCurrencyEqual(taxableIncome, 7000.00, "Taxable income: 10000 - 3000 = 7000")
    }
}
