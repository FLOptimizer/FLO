//  FLOCarryforwardAndPartnerTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - TaxCarryforward + PartnerAllocation model tests
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  COVERS:
//  - Carryforward utilization (partial, full, over-utilization clamping)
//  - Status transitions (active → partiallyUtilized → fullyUtilized, expired)
//  - Utilization percentage / amountUtilized math
//  - Partner capital account math (ending balance, outside basis, §752 debt)
//  - Loss deductibility by basis
//  - Default profit/loss share fallback to ownership percentage

import XCTest
@testable import FLO

final class FLOCarryforwardAndPartnerTests: XCTestCase {

    let precision: Double = 0.01

    // MARK: - Carryforward Utilization

    func testCarryforward_StartsActiveWithFullRemaining() {
        let cf = TaxCarryforward(type: .netOperatingLoss, originYear: 2024, originalAmount: 10_000)
        XCTAssertEqual(cf.status, .active)
        XCTAssertEqual(cf.remainingAmount, 10_000, accuracy: precision)
        XCTAssertEqual(cf.amountUtilized, 0, accuracy: precision)
        XCTAssertTrue(cf.isActive)
    }

    func testCarryforward_PartialUtilization() {
        let cf = TaxCarryforward(type: .netOperatingLoss, originYear: 2024, originalAmount: 10_000)
        cf.utilize(amount: 4_000)

        XCTAssertEqual(cf.status, .partiallyUtilized)
        XCTAssertEqual(cf.remainingAmount, 6_000, accuracy: precision)
        XCTAssertEqual(cf.amountUtilized, 4_000, accuracy: precision)
        XCTAssertEqual(cf.utilizationPercentage, 0.4, accuracy: 0.0001)
        XCTAssertTrue(cf.isActive, "Partially utilized carryforwards remain active")
    }

    func testCarryforward_FullUtilization() {
        let cf = TaxCarryforward(type: .capitalLoss, originYear: 2024, originalAmount: 3_000)
        cf.utilize(amount: 3_000)

        XCTAssertEqual(cf.status, .fullyUtilized)
        XCTAssertEqual(cf.remainingAmount, 0, accuracy: precision)
        XCTAssertFalse(cf.isActive)
    }

    func testCarryforward_OverUtilization_ClampsToRemaining() {
        let cf = TaxCarryforward(type: .capitalLoss, originYear: 2024, originalAmount: 3_000)
        cf.utilize(amount: 5_000)

        XCTAssertEqual(cf.remainingAmount, 0, accuracy: precision, "Cannot utilize more than remaining")
        XCTAssertEqual(cf.amountUtilized, 3_000, accuracy: precision)
        XCTAssertEqual(cf.status, .fullyUtilized)
    }

    func testCarryforward_SequentialUtilization() {
        let cf = TaxCarryforward(type: .suspendedLoss704d, originYear: 2024, originalAmount: 8_000)
        cf.utilize(amount: 3_000)
        cf.utilize(amount: 3_000)

        XCTAssertEqual(cf.remainingAmount, 2_000, accuracy: precision)
        XCTAssertEqual(cf.status, .partiallyUtilized)

        cf.utilize(amount: 2_000)
        XCTAssertEqual(cf.status, .fullyUtilized)
    }

    func testCarryforward_MarkExpired() {
        let cf = TaxCarryforward(
            type: .charitableContribution,
            originYear: 2020,
            originalAmount: 1_000,
            expirationYear: 2025
        )
        XCTAssertTrue(cf.canExpire)

        cf.markExpired()
        XCTAssertEqual(cf.status, .expired)
        XCTAssertFalse(cf.isActive)
    }

    func testCarryforward_PartialRemainingAmountInitializer() {
        let cf = TaxCarryforward(
            type: .netOperatingLoss,
            originYear: 2023,
            originalAmount: 10_000,
            remainingAmount: 7_500
        )
        XCTAssertEqual(cf.remainingAmount, 7_500, accuracy: precision)
        XCTAssertEqual(cf.amountUtilized, 2_500, accuracy: precision)
    }

    func testCarryforward_ZeroOriginalAmount_UtilizationPercentageIsZero() {
        let cf = TaxCarryforward(type: .other, originYear: 2024, originalAmount: 0)
        XCTAssertEqual(cf.utilizationPercentage, 0, "Must not divide by zero")
    }

    // MARK: - Partner Capital Accounts

    func testPartner_EndingCapitalBalance() {
        let partner = PartnerAllocation(
            partnerName: "Alex",
            ownershipPercentage: 0.5,
            capitalContributed: 2_000,
            beginningCapitalBalance: 5_000
        )
        // 5,000 beginning + 2,000 contributed + 3,000 income
        XCTAssertEqual(partner.endingCapitalBalance(allocatedIncome: 3_000), 10_000, accuracy: precision)
        // Loss reduces capital
        XCTAssertEqual(partner.endingCapitalBalance(allocatedIncome: -4_000), 3_000, accuracy: precision)
    }

    func testPartner_OutsideBasis_IncludesDebtAllocation() {
        let partner = PartnerAllocation(
            partnerName: "Alex",
            ownershipPercentage: 0.5,
            beginningCapitalBalance: 1_000,
            debtAllocation: 4_000
        )
        // 1,000 capital + 4,000 §752 debt
        XCTAssertEqual(partner.outsideBasis(allocatedIncome: 0), 5_000, accuracy: precision)
    }

    func testPartner_OutsideBasis_FlooredAtZero() {
        let partner = PartnerAllocation(
            partnerName: "Alex",
            ownershipPercentage: 1.0,
            beginningCapitalBalance: 1_000
        )
        XCTAssertEqual(partner.outsideBasis(allocatedIncome: -5_000), 0, accuracy: precision,
                       "Outside basis cannot go negative")
    }

    func testPartner_CanDeductLoss_ByBasis() {
        let funded = PartnerAllocation(
            partnerName: "Funded",
            ownershipPercentage: 1.0,
            beginningCapitalBalance: 10_000
        )
        XCTAssertTrue(funded.canDeductLoss(allocatedLoss: -4_000))

        let unfunded = PartnerAllocation(
            partnerName: "Unfunded",
            ownershipPercentage: 1.0,
            beginningCapitalBalance: 0
        )
        XCTAssertFalse(unfunded.canDeductLoss(allocatedLoss: -4_000))
    }

    func testPartner_ProfitAndLossShares_DefaultToOwnership() {
        let partner = PartnerAllocation(partnerName: "Alex", ownershipPercentage: 0.35)
        XCTAssertEqual(partner.profitSharePercentage, 0.35, accuracy: 0.0001)
        XCTAssertEqual(partner.lossSharePercentage, 0.35, accuracy: 0.0001)
    }

    func testPartner_ExplicitSharesOverrideOwnership() {
        let partner = PartnerAllocation(
            partnerName: "Alex",
            ownershipPercentage: 0.50,
            profitSharePercentage: 0.70,
            lossSharePercentage: 0.30
        )
        XCTAssertEqual(partner.profitSharePercentage, 0.70, accuracy: 0.0001)
        XCTAssertEqual(partner.lossSharePercentage, 0.30, accuracy: 0.0001)
    }

    func testPartner_OwnershipDisplay() {
        XCTAssertEqual(PartnerAllocation(partnerName: "A", ownershipPercentage: 0.5).ownershipDisplay, "50%")
        XCTAssertEqual(PartnerAllocation(partnerName: "B", ownershipPercentage: 1.0).ownershipDisplay, "100%")
    }
}
