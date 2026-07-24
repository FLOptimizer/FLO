//  FLORecurringDetectionTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - RecurringDetectionService Tests
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE: Validate the recurring detection engine's data structures,
//  confidence scoring, pattern model behavior, and configuration constants.
//
//  COVERS:
//  - DetectedRecurringPattern model properties
//  - Confidence label thresholds
//  - Confidence color mapping
//  - Summary text generation
//  - Service configuration constants
//  - ForecastHorizon enum behavior

import XCTest
@testable import FLO

final class FLORecurringDetectionTests: XCTestCase {

    // MARK: - Test Helpers

    /// Create a pattern with specified values for testing.
    private func makePattern(
        merchantName: String = "Netflix",
        averageAmount: Double = 15.99,
        medianAmount: Double = 15.99,
        frequency: RecurrenceFrequency = .monthly,
        confidence: Double = 0.85,
        transactionCount: Int = 5,
        isIncome: Bool = false
    ) -> DetectedRecurringPattern {
        DetectedRecurringPattern(
            id: UUID(),
            merchantName: merchantName,
            averageAmount: averageAmount,
            medianAmount: medianAmount,
            amountMin: averageAmount * 0.9,
            amountMax: averageAmount * 1.1,
            detectedFrequency: frequency,
            confidence: confidence,
            transactionCount: transactionCount,
            isIncome: isIncome,
            financeType: .personal,
            mostRecentDate: Date(),
            estimatedNextDate: Calendar.current.date(byAdding: .month, value: 1, to: Date()),
            matchingTransactionIDs: (0..<transactionCount).map { _ in UUID() },
            suggestedCategoryID: nil,
            suggestedCategoryName: nil,
            suggestedAccountID: nil,
            suggestedAccountName: nil
        )
    }
}

// MARK: - Confidence Labels

extension FLORecurringDetectionTests {

    func testConfidenceLabel_HighAt80Percent() {
        let pattern = makePattern(confidence: 0.80)
        XCTAssertEqual(pattern.confidenceLabel, "High")
    }

    func testConfidenceLabel_HighAbove80Percent() {
        let pattern = makePattern(confidence: 0.95)
        XCTAssertEqual(pattern.confidenceLabel, "High")
    }

    func testConfidenceLabel_MediumAt60Percent() {
        let pattern = makePattern(confidence: 0.60)
        XCTAssertEqual(pattern.confidenceLabel, "Medium")
    }

    func testConfidenceLabel_MediumAt79Percent() {
        let pattern = makePattern(confidence: 0.79)
        XCTAssertEqual(pattern.confidenceLabel, "Medium")
    }

    func testConfidenceLabel_LowBelow60Percent() {
        let pattern = makePattern(confidence: 0.50)
        XCTAssertEqual(pattern.confidenceLabel, "Low")
    }

    func testConfidenceLabel_LowAtZero() {
        let pattern = makePattern(confidence: 0.0)
        XCTAssertEqual(pattern.confidenceLabel, "Low")
    }
}

// MARK: - Confidence Colors

extension FLORecurringDetectionTests {

    func testConfidenceColor_GreenForHigh() {
        let pattern = makePattern(confidence: 0.85)
        XCTAssertEqual(pattern.confidenceColor, "green")
    }

    func testConfidenceColor_OrangeForMedium() {
        let pattern = makePattern(confidence: 0.65)
        XCTAssertEqual(pattern.confidenceColor, "orange")
    }

    func testConfidenceColor_YellowForLow() {
        let pattern = makePattern(confidence: 0.40)
        XCTAssertEqual(pattern.confidenceColor, "yellow")
    }
}

// MARK: - Formatted Amount

extension FLORecurringDetectionTests {

    func testFormattedAmount_USD() {
        let pattern = makePattern(averageAmount: 15.99)
        XCTAssertTrue(pattern.formattedAmount.contains("15.99"),
                       "Formatted amount should contain 15.99, got: \(pattern.formattedAmount)")
    }

    func testFormattedAmount_LargeValue() {
        let pattern = makePattern(averageAmount: 1500.00)
        XCTAssertTrue(pattern.formattedAmount.contains("1,500") || pattern.formattedAmount.contains("1500"),
                       "Should format large amount, got: \(pattern.formattedAmount)")
    }
}

// MARK: - Summary Text

extension FLORecurringDetectionTests {

    func testSummaryText_Expense() {
        let pattern = makePattern(
            averageAmount: 15.99,
            frequency: .monthly,
            isIncome: false
        )
        XCTAssertTrue(pattern.summaryText.contains("Monthly"), "Should contain frequency")
        XCTAssertTrue(pattern.summaryText.contains("expense"), "Should say expense")
    }

    func testSummaryText_Income() {
        let pattern = makePattern(
            averageAmount: 3000.00,
            frequency: .biweekly,
            isIncome: true
        )
        XCTAssertTrue(pattern.summaryText.contains("Bi-weekly") || pattern.summaryText.contains("Biweekly") || pattern.summaryText.lowercased().contains("bi"),
                       "Should contain biweekly frequency, got: \(pattern.summaryText)")
        XCTAssertTrue(pattern.summaryText.contains("income"), "Should say income")
    }

    func testSummaryText_ContainsAmount() {
        let pattern = makePattern(averageAmount: 49.99)
        XCTAssertTrue(pattern.summaryText.contains("49.99"),
                       "Summary should contain amount, got: \(pattern.summaryText)")
    }
}

// MARK: - Service Configuration Constants

extension FLORecurringDetectionTests {

    @MainActor
    func testMinimumOccurrences_IsReasonable() {
        XCTAssertEqual(RecurringDetectionService.minimumOccurrences, 3,
                       "Need at least 3 occurrences to detect a pattern")
    }

    @MainActor
    func testAmountTolerance_IsTenPercent() {
        XCTAssertEqual(RecurringDetectionService.amountTolerancePercent, 0.10, accuracy: 0.001)
    }

    @MainActor
    func testMinimumConfidence_IsHalf() {
        XCTAssertEqual(RecurringDetectionService.minimumConfidence, 0.50, accuracy: 0.001)
    }

    @MainActor
    func testAnalysisWindow_Is12Months() {
        XCTAssertEqual(RecurringDetectionService.analysisWindowMonths, 12)
    }
}

// MARK: - Pattern Identity & Matching

extension FLORecurringDetectionTests {

    func testPattern_HasUniqueID() {
        let pattern1 = makePattern()
        let pattern2 = makePattern()
        XCTAssertNotEqual(pattern1.id, pattern2.id,
                          "Each pattern should have a unique ID")
    }

    func testPattern_StoresTransactionCount() {
        let pattern = makePattern(transactionCount: 7)
        XCTAssertEqual(pattern.transactionCount, 7)
        XCTAssertEqual(pattern.matchingTransactionIDs.count, 7)
    }

    func testPattern_StoresFrequency() {
        let weekly = makePattern(frequency: .weekly)
        let monthly = makePattern(frequency: .monthly)
        let quarterly = makePattern(frequency: .quarterly)

        XCTAssertEqual(weekly.detectedFrequency, .weekly)
        XCTAssertEqual(monthly.detectedFrequency, .monthly)
        XCTAssertEqual(quarterly.detectedFrequency, .quarterly)
    }
}

// MARK: - Amount Range

extension FLORecurringDetectionTests {

    func testPattern_AmountRange() {
        let pattern = makePattern(averageAmount: 100.0)
        XCTAssertLessThanOrEqual(pattern.amountMin, pattern.averageAmount)
        XCTAssertGreaterThanOrEqual(pattern.amountMax, pattern.averageAmount)
    }

    func testPattern_MedianVsAverage() {
        // When median equals average, amounts are consistent
        let pattern = makePattern(averageAmount: 50.0, medianAmount: 50.0)
        XCTAssertEqual(pattern.medianAmount, pattern.averageAmount, accuracy: 0.01)
    }
}

// MARK: - Edge Cases

extension FLORecurringDetectionTests {

    func testPattern_ZeroAmount() {
        let pattern = makePattern(averageAmount: 0.0, medianAmount: 0.0)
        XCTAssertTrue(pattern.formattedAmount.contains("0.00"),
                       "Should format zero amount, got: \(pattern.formattedAmount)")
    }

    func testPattern_EmptyMerchantName() {
        let pattern = makePattern(merchantName: "")
        XCTAssertEqual(pattern.merchantName, "")
    }

    func testPattern_HighConfidenceBoundary() {
        // Exactly at 0.80 boundary
        let at80 = makePattern(confidence: 0.80)
        let below80 = makePattern(confidence: 0.7999)
        XCTAssertEqual(at80.confidenceLabel, "High")
        XCTAssertEqual(below80.confidenceLabel, "Medium")
    }

    func testPattern_MediumConfidenceBoundary() {
        // Exactly at 0.60 boundary
        let at60 = makePattern(confidence: 0.60)
        let below60 = makePattern(confidence: 0.5999)
        XCTAssertEqual(at60.confidenceLabel, "Medium")
        XCTAssertEqual(below60.confidenceLabel, "Low")
    }
}
