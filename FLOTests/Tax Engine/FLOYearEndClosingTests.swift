//  FLOYearEndClosingTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Year-end closing workflow tests
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  COVERS:
//  - Carryforward rolling (expired items marked, active items preserved)
//  - Suspended loss carryforward creation from §704(d) zero-basis losses
//  - Partner capital reset (ending → next year's beginning)
//  - Non-partnership entities skip partnership-only steps
//  - Preview (dry run) makes no model changes

import XCTest
import SwiftData
@testable import FLO

@MainActor
final class FLOYearEndClosingTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    let service = YearEndClosingService.shared
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

    private func makeBusiness(type: BusinessType = .llc) -> BusinessProfile {
        let business = BusinessProfile(
            businessName: "Test LLC",
            email: "test@example.com",
            businessType: type
        )
        context.insert(business)
        return business
    }

    private func addPartner(
        _ name: String,
        to business: BusinessProfile,
        ownership: Double,
        beginningCapital: Double = 0
    ) -> PartnerAllocation {
        let partner = PartnerAllocation(
            partnerName: name,
            ownershipPercentage: ownership,
            beginningCapitalBalance: beginningCapital
        )
        context.insert(partner)
        partner.businessProfile = business
        return partner
    }

    private func addCarryforward(
        to business: BusinessProfile,
        type: CarryforwardType = .netOperatingLoss,
        originYear: Int = 2024,
        amount: Double = 5_000,
        expirationYear: Int? = nil
    ) -> TaxCarryforward {
        let cf = TaxCarryforward(
            type: type,
            originYear: originYear,
            originalAmount: amount,
            expirationYear: expirationYear
        )
        context.insert(cf)
        cf.businessProfile = business
        return cf
    }

    private func makeIncomeTransactions(amount: Double, year: Int = 2025) -> [Transaction] {
        let category = FLO.Category(name: "Sales", isIncome: true, isBusiness: true, scheduleCLine: .line1_grossReceipts)
        context.insert(category)
        let txn = Transaction(
            amount: amount,
            date: date(year: year),
            category: category,
            financeType: .business
        )
        context.insert(txn)
        return [txn]
    }

    private func makeExpenseTransactions(amount: Double, year: Int = 2025) -> [Transaction] {
        let category = FLO.Category(name: "Supplies", isBusiness: true, scheduleCLine: .line22_supplies)
        context.insert(category)
        let txn = Transaction(
            amount: amount,
            date: date(year: year),
            category: category,
            financeType: .business
        )
        context.insert(txn)
        return [txn]
    }

    // MARK: - Carryforward Rolling

    func testClose_ExpiredCarryforward_IsMarkedExpired() {
        let business = makeBusiness()
        let expiring = addCarryforward(to: business, type: .charitableContribution, expirationYear: 2025)
        let persisting = addCarryforward(to: business, type: .netOperatingLoss)

        _ = service.executeClose(business: business, transactions: [], taxYear: 2025, context: context)

        XCTAssertEqual(expiring.status, .expired)
        XCTAssertEqual(persisting.status, .active, "Non-expiring carryforwards stay active")
    }

    func testClose_FutureExpirationCarryforward_StaysActive() {
        let business = makeBusiness()
        let cf = addCarryforward(to: business, type: .charitableContribution, expirationYear: 2027)

        _ = service.executeClose(business: business, transactions: [], taxYear: 2025, context: context)

        XCTAssertEqual(cf.status, .active)
    }

    // MARK: - Suspended Losses (§704(d))

    func testClose_ZeroBasisLoss_CreatesSuspendedLossCarryforward() {
        let business = makeBusiness(type: .llc)
        let partner = addPartner("Alex", to: business, ownership: 1.0, beginningCapital: 0)
        let transactions = makeExpenseTransactions(amount: 5_000)

        _ = service.executeClose(business: business, transactions: transactions, taxYear: 2025, context: context)

        let suspendedCFs = (business.carryforwards ?? []).filter { $0.type == .suspendedLoss704d }
        XCTAssertEqual(suspendedCFs.count, 1)
        XCTAssertEqual(suspendedCFs.first?.originalAmount ?? 0, 5_000, accuracy: precision)
        XCTAssertEqual(suspendedCFs.first?.partnerName, "Alex")
        XCTAssertEqual(suspendedCFs.first?.originYear, 2025)
        XCTAssertTrue(partner.hasLossesSuspended)
        XCTAssertEqual(partner.suspendedLossAmount, 5_000, accuracy: precision)
    }

    func testClose_ProfitableYear_NoSuspendedLossCreated() {
        let business = makeBusiness(type: .llc)
        _ = addPartner("Alex", to: business, ownership: 1.0)
        let transactions = makeIncomeTransactions(amount: 10_000)

        _ = service.executeClose(business: business, transactions: transactions, taxYear: 2025, context: context)

        let suspendedCFs = (business.carryforwards ?? []).filter { $0.type == .suspendedLoss704d }
        XCTAssertTrue(suspendedCFs.isEmpty)
    }

    func testClose_SoleProprietorship_SkipsSuspendedLossStep() {
        let business = makeBusiness(type: .soleProprietorship)
        let transactions = makeExpenseTransactions(amount: 5_000)

        let summary = service.executeClose(business: business, transactions: transactions, taxYear: 2025, context: context)

        let step = summary.steps.first { $0.stepName == "Suspended Losses" }
        XCTAssertNotNil(step)
        XCTAssertEqual(step?.itemsProcessed, 0)
        if case .skipped = step!.status {} else {
            XCTFail("Suspended losses step should be skipped for non-partnerships")
        }
        XCTAssertTrue((business.carryforwards ?? []).isEmpty)
    }

    // MARK: - Partner Capital Reset

    func testClose_RollsEndingCapitalIntoBeginningCapital() {
        let business = makeBusiness(type: .llc)
        let partnerA = addPartner("Alex", to: business, ownership: 0.6, beginningCapital: 1_000)
        let partnerB = addPartner("Blake", to: business, ownership: 0.4, beginningCapital: 500)
        let transactions = makeIncomeTransactions(amount: 10_000)

        _ = service.executeClose(business: business, transactions: transactions, taxYear: 2025, context: context)

        // Ending capital = beginning + allocated share of 10,000
        XCTAssertEqual(partnerA.beginningCapitalBalance, 1_000 + 6_000, accuracy: precision)
        XCTAssertEqual(partnerB.beginningCapitalBalance, 500 + 4_000, accuracy: precision)
    }

    // MARK: - Closing Summary

    func testClose_SummaryReportsAllFourSteps() {
        let business = makeBusiness(type: .llc)
        _ = addPartner("Alex", to: business, ownership: 1.0)

        let summary = service.executeClose(business: business, transactions: [], taxYear: 2025, context: context)

        let stepNames = summary.steps.map(\.stepName)
        XCTAssertTrue(stepNames.contains("Roll Carryforwards"))
        XCTAssertTrue(stepNames.contains("Suspended Losses"))
        XCTAssertTrue(stepNames.contains("Reset Partner Capital"))
        XCTAssertTrue(stepNames.contains("Depreciation Review"))
        XCTAssertEqual(summary.taxYear, 2025)
    }

    func testCloseAll_ProcessesEveryBusiness() {
        let llc = makeBusiness(type: .llc)
        _ = addPartner("Alex", to: llc, ownership: 1.0)
        let soleProp = makeBusiness(type: .soleProprietorship)

        let result = service.executeCloseAll(
            businesses: [llc, soleProp],
            transactions: [],
            taxYear: 2025,
            context: context
        )

        XCTAssertEqual(result.businessSummaries.count, 2)
        XCTAssertEqual(result.taxYear, 2025)
    }

    // MARK: - Preview (Dry Run)

    func testPreview_MakesNoModelChanges() {
        let business = makeBusiness(type: .llc)
        let partner = addPartner("Alex", to: business, ownership: 1.0, beginningCapital: 0)
        let expiring = addCarryforward(to: business, expirationYear: 2025)
        let transactions = makeExpenseTransactions(amount: 5_000)

        let preview = service.generatePreview(business: business, transactions: transactions, taxYear: 2025)

        // Preview reports what would happen…
        XCTAssertEqual(preview.carryforwardsToRoll.count, 1)
        XCTAssertTrue(preview.carryforwardsToRoll.first!.action.contains("expired"))
        XCTAssertEqual(preview.suspendedLossAlerts.count, 1)
        XCTAssertEqual(preview.suspendedLossAlerts.first?.amount ?? 0, 5_000, accuracy: precision)

        // …but changes nothing
        XCTAssertEqual(expiring.status, .active)
        XCTAssertFalse(partner.hasLossesSuspended)
        XCTAssertEqual(partner.beginningCapitalBalance, 0, accuracy: precision)
        XCTAssertTrue((business.carryforwards ?? []).filter { $0.type == .suspendedLoss704d }.isEmpty)
    }

    func testPreview_AssetAdvance_ReportsCurrentAndNextYearDepreciation() {
        let business = makeBusiness(type: .llc)
        let asset = DepreciableAsset(
            name: "Mower",
            cost: 10_000,
            placedInServiceDate: date(year: 2025)
        )
        context.insert(asset)
        asset.businessProfile = business

        let preview = service.generatePreview(business: business, transactions: [], taxYear: 2025)

        XCTAssertEqual(preview.assetsToAdvance.count, 1)
        let advance = preview.assetsToAdvance[0]
        XCTAssertEqual(advance.currentYearDepreciation, 2_000, accuracy: precision)
        XCTAssertEqual(advance.nextYearDepreciation, 3_200, accuracy: precision)
        XCTAssertEqual(advance.remainingBasis, 8_000, accuracy: precision)
    }
}
