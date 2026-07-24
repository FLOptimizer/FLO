//  FLOTaxLineAggregationTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Tax line aggregation + K-1 allocation tests
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  COVERS:
//  - aggregateByFormLine: grouping, year/transfer/personal filtering
//  - Meals 50% deduction rate
//  - Cross-form translation (Schedule C category → Form 1065 / Schedule F lines)
//  - Sorted output (income lines before expense lines)
//  - partnerAllocations: profit/loss splits, capital accounts, SE earnings
//  - Suspended loss detection (§704(d) basis limitation)
//  - generateBusinessSummary: ordinary income including depreciation

import XCTest
import SwiftData
@testable import FLO

@MainActor
final class FLOTaxLineAggregationTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    let service = TaxLineAggregationService.shared
    let precision: Double = 0.01

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

    private func date(year: Int, month: Int = 6, day: Int = 15) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)!
    }

    private func makeBusiness(type: BusinessType = .soleProprietorship) -> BusinessProfile {
        let business = BusinessProfile(
            businessName: "Test Business",
            email: "test@example.com",
            businessType: type
        )
        context.insert(business)
        return business
    }

    private func makeCategory(_ name: String, line: ScheduleCLine, isIncome: Bool = false) -> FLO.Category {
        let category = FLO.Category(
            name: name,
            isIncome: isIncome,
            isBusiness: true,
            scheduleCLine: line
        )
        context.insert(category)
        return category
    }

    @discardableResult
    private func makeTransaction(
        amount: Double,
        category: FLO.Category?,
        year: Int = 2025,
        financeType: Transaction.FinanceType = .business,
        isTransfer: Bool = false
    ) -> Transaction {
        let txn = Transaction(
            amount: amount,
            date: date(year: year),
            category: category,
            financeType: financeType,
            isTransfer: isTransfer
        )
        context.insert(txn)
        return txn
    }

    private func addPartner(
        _ name: String,
        to business: BusinessProfile,
        ownership: Double,
        beginningCapital: Double = 0,
        contributed: Double = 0,
        debt: Double = 0
    ) -> PartnerAllocation {
        let partner = PartnerAllocation(
            partnerName: name,
            ownershipPercentage: ownership,
            capitalContributed: contributed,
            beginningCapitalBalance: beginningCapital,
            debtAllocation: debt
        )
        context.insert(partner)
        partner.businessProfile = business
        return partner
    }

    // MARK: - Aggregation

    func testAggregate_GroupsByFormLine() {
        let business = makeBusiness()
        let income = makeCategory("Sales", line: .line1_grossReceipts, isIncome: true)
        let supplies = makeCategory("Supplies", line: .line22_supplies)

        let transactions = [
            makeTransaction(amount: 1_000, category: income),
            makeTransaction(amount: 2_000, category: income),
            makeTransaction(amount: 500, category: supplies)
        ]

        let totals = service.aggregateByFormLine(business: business, transactions: transactions, year: 2025)

        XCTAssertEqual(totals.count, 2)
        let incomeLine = totals.first { $0.taxFormLine == .schC_line1_grossReceipts }
        XCTAssertEqual(incomeLine?.grossAmount ?? 0, 3_000, accuracy: precision)
        XCTAssertEqual(incomeLine?.transactionCount, 2)

        let suppliesLine = totals.first { $0.taxFormLine == .schC_line22_supplies }
        XCTAssertEqual(suppliesLine?.grossAmount ?? 0, 500, accuracy: precision)
        XCTAssertEqual(suppliesLine?.deductibleAmount ?? 0, 500, accuracy: precision)
    }

    func testAggregate_ExcludesOtherYearsTransfersAndPersonal() {
        let business = makeBusiness()
        let supplies = makeCategory("Supplies", line: .line22_supplies)

        let transactions = [
            makeTransaction(amount: 100, category: supplies),                        // counted
            makeTransaction(amount: 200, category: supplies, year: 2024),            // wrong year
            makeTransaction(amount: 300, category: supplies, financeType: .personal),// personal
            makeTransaction(amount: 400, category: supplies, isTransfer: true),      // transfer
            makeTransaction(amount: 500, category: nil)                              // no category
        ]

        let totals = service.aggregateByFormLine(business: business, transactions: transactions, year: 2025)

        XCTAssertEqual(totals.count, 1)
        XCTAssertEqual(totals[0].grossAmount, 100, accuracy: precision)
        XCTAssertEqual(totals[0].transactionCount, 1)
    }

    func testAggregate_MealsAreFiftyPercentDeductible() {
        let business = makeBusiness()
        let meals = makeCategory("Business Meals", line: .line24b_meals)

        let totals = service.aggregateByFormLine(
            business: business,
            transactions: [makeTransaction(amount: 200, category: meals)],
            year: 2025
        )

        XCTAssertEqual(totals.count, 1)
        XCTAssertEqual(totals[0].taxFormLine, .schC_line24b_meals)
        XCTAssertEqual(totals[0].grossAmount, 200, accuracy: precision)
        XCTAssertEqual(totals[0].deductibleAmount, 100, accuracy: precision, "Meals deduct at 50%")
    }

    func testAggregate_SortsIncomeLinesBeforeExpenseLines() {
        let business = makeBusiness()
        let supplies = makeCategory("Supplies", line: .line22_supplies)
        let income = makeCategory("Sales", line: .line1_grossReceipts, isIncome: true)

        let totals = service.aggregateByFormLine(
            business: business,
            transactions: [
                makeTransaction(amount: 500, category: supplies),
                makeTransaction(amount: 1_000, category: income)
            ],
            year: 2025
        )

        XCTAssertEqual(totals.first?.taxFormLine, .schC_line1_grossReceipts,
                       "Line 1 income should sort before line 22 supplies")
    }

    // MARK: - Cross-Form Translation

    func testResolvedFormLine_ScheduleCCategoryOnPartnership_TranslatesToForm1065() {
        let business = makeBusiness(type: .llc)
        let supplies = makeCategory("Supplies", line: .line22_supplies)

        let totals = service.aggregateByFormLine(
            business: business,
            transactions: [makeTransaction(amount: 500, category: supplies)],
            year: 2025
        )

        XCTAssertEqual(totals.count, 1)
        XCTAssertEqual(totals[0].taxFormLine, .f1065_line20_otherDeductions,
                       "Schedule C supplies should map to Form 1065 other deductions")
        XCTAssertEqual(totals[0].formType, .form1065)
    }

    func testResolvedFormLine_GrossReceiptsOnFarm_TranslatesToScheduleF() {
        let business = makeBusiness(type: .farm)
        let income = makeCategory("Sales", line: .line1_grossReceipts, isIncome: true)

        let totals = service.aggregateByFormLine(
            business: business,
            transactions: [makeTransaction(amount: 10_000, category: income)],
            year: 2025
        )

        XCTAssertEqual(totals.count, 1)
        XCTAssertEqual(totals[0].taxFormLine, .schF_line1a_salesLivestock)
        XCTAssertTrue(totals[0].isIncome)
    }

    func testResolvedFormLine_ExplicitTaxFormLineMatchingForm_UsedDirectly() {
        let business = makeBusiness(type: .llc)
        let category = makeCategory("Repairs", line: .line21_repairsMaintenance)
        category.taxFormLine = .f1065_line11_repairsMaintenance

        let txn = makeTransaction(amount: 250, category: category)
        let resolved = service.resolvedFormLine(for: txn, formType: .form1065)
        XCTAssertEqual(resolved, .f1065_line11_repairsMaintenance)
    }

    // MARK: - Partner K-1 Allocations

    func testPartnerAllocations_SplitsProfitByShare() {
        let business = makeBusiness(type: .llc)
        let partnerA = addPartner("Alex", to: business, ownership: 0.60, beginningCapital: 1_000)
        let partnerB = addPartner("Blake", to: business, ownership: 0.40, beginningCapital: 500)

        let income = makeCategory("Sales", line: .line1_grossReceipts, isIncome: true)
        let supplies = makeCategory("Supplies", line: .line22_supplies)
        let transactions = [
            makeTransaction(amount: 10_000, category: income),
            makeTransaction(amount: 2_000, category: supplies)
        ]

        let totals = service.aggregateByFormLine(business: business, transactions: transactions, year: 2025)
        let k1s = service.partnerAllocations(business: business, formLineTotals: totals, year: 2025)

        XCTAssertEqual(k1s.count, 2)
        // Net ordinary income: 10,000 − 2,000 = 8,000
        let alexK1 = k1s.first { $0.partner.id == partnerA.id }
        let blakeK1 = k1s.first { $0.partner.id == partnerB.id }

        XCTAssertEqual(alexK1?.ordinaryIncome ?? 0, 4_800, accuracy: precision)
        XCTAssertEqual(blakeK1?.ordinaryIncome ?? 0, 3_200, accuracy: precision)
        XCTAssertEqual(alexK1?.endingCapital ?? 0, 1_000 + 4_800, accuracy: precision)
        XCTAssertEqual(blakeK1?.endingCapital ?? 0, 500 + 3_200, accuracy: precision)
        XCTAssertEqual(alexK1?.selfEmploymentEarnings ?? 0, 4_800, accuracy: precision,
                       "LLC ordinary income is SE income")
        XCTAssertEqual(alexK1?.suspendedLossAmount ?? -1, 0)
        XCTAssertEqual(alexK1?.lossDeductible, true)
    }

    func testPartnerAllocations_LossWithZeroBasis_IsSuspended() {
        let business = makeBusiness(type: .llc)
        _ = addPartner("Alex", to: business, ownership: 1.0, beginningCapital: 0)

        let supplies = makeCategory("Supplies", line: .line22_supplies)
        let transactions = [makeTransaction(amount: 5_000, category: supplies)]

        let totals = service.aggregateByFormLine(business: business, transactions: transactions, year: 2025)
        let k1s = service.partnerAllocations(business: business, formLineTotals: totals, year: 2025)

        XCTAssertEqual(k1s.count, 1)
        XCTAssertEqual(k1s[0].ordinaryIncome, -5_000, accuracy: precision)
        XCTAssertFalse(k1s[0].lossDeductible, "No basis → loss not deductible")
        XCTAssertEqual(k1s[0].suspendedLossAmount, 5_000, accuracy: precision)
        XCTAssertEqual(k1s[0].outsideBasis, 0, accuracy: precision)
    }

    func testPartnerAllocations_LossWithDebtBasis_IsDeductible() {
        let business = makeBusiness(type: .llc)
        // §752 debt allocation gives outside basis even with zero capital
        _ = addPartner("Alex", to: business, ownership: 1.0, beginningCapital: 0, debt: 10_000)

        let supplies = makeCategory("Supplies", line: .line22_supplies)
        let totals = service.aggregateByFormLine(
            business: business,
            transactions: [makeTransaction(amount: 5_000, category: supplies)],
            year: 2025
        )
        let k1s = service.partnerAllocations(business: business, formLineTotals: totals, year: 2025)

        XCTAssertTrue(k1s[0].lossDeductible)
        XCTAssertEqual(k1s[0].suspendedLossAmount, 0, accuracy: precision)
        XCTAssertEqual(k1s[0].outsideBasis, 5_000, accuracy: precision, "0 − 5,000 loss + 10,000 debt")
    }

    func testPartnerAllocations_NoPartners_ReturnsEmpty() {
        let business = makeBusiness(type: .llc)
        let k1s = service.partnerAllocations(business: business, formLineTotals: [], year: 2025)
        XCTAssertTrue(k1s.isEmpty)
    }

    // MARK: - Business Summary

    func testGenerateBusinessSummary_OrdinaryIncomeIncludesDepreciation() {
        let business = makeBusiness()
        let income = makeCategory("Sales", line: .line1_grossReceipts, isIncome: true)
        let supplies = makeCategory("Supplies", line: .line22_supplies)

        // $10,000 5-year asset placed in service 2025 → $2,000 year-1 MACRS
        let asset = DepreciableAsset(
            name: "Mower",
            cost: 10_000,
            placedInServiceDate: date(year: 2025)
        )
        context.insert(asset)
        asset.businessProfile = business

        let transactions = [
            makeTransaction(amount: 20_000, category: income),
            makeTransaction(amount: 3_000, category: supplies)
        ]

        let summary = service.generateBusinessSummary(business: business, transactions: transactions, year: 2025)

        XCTAssertEqual(summary.totalIncome, 20_000, accuracy: precision)
        XCTAssertEqual(summary.totalDeductions, 3_000, accuracy: precision)
        XCTAssertEqual(summary.depreciationTotal, 2_000, accuracy: precision)
        XCTAssertEqual(summary.ordinaryIncome, 15_000, accuracy: precision,
                       "20,000 − 3,000 − 2,000 depreciation")
        XCTAssertEqual(summary.formType, .scheduleC)
    }

    func testGenerateBusinessSummary_IncludesOnlyActiveCarryforwards() {
        let business = makeBusiness()

        let active = TaxCarryforward(type: .netOperatingLoss, originYear: 2024, originalAmount: 4_000)
        context.insert(active)
        active.businessProfile = business

        let usedUp = TaxCarryforward(type: .capitalLoss, originYear: 2023, originalAmount: 1_000)
        context.insert(usedUp)
        usedUp.businessProfile = business
        usedUp.utilize(amount: 1_000)

        let summary = service.generateBusinessSummary(business: business, transactions: [], year: 2025)

        XCTAssertEqual(summary.carryforwards.count, 1)
        XCTAssertEqual(summary.carryforwards.first?.type, .netOperatingLoss)
    }

    func testGenerateBusinessSummary_RentalProperty_NoSelfEmploymentEarnings() {
        let business = makeBusiness(type: .rentalProperty)
        _ = addPartner("Alex", to: business, ownership: 1.0)

        let income = makeCategory("Rents", line: .line1_grossReceipts, isIncome: true)
        let summary = service.generateBusinessSummary(
            business: business,
            transactions: [makeTransaction(amount: 12_000, category: income)],
            year: 2025
        )

        XCTAssertEqual(summary.formType, .scheduleE)
        XCTAssertEqual(summary.partnerSummaries.first?.selfEmploymentEarnings ?? -1, 0,
                       "Rental income is not subject to SE tax")
    }
}
