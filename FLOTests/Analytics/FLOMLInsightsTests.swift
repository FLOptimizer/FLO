//  FLOMLInsightsTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - ML Insights Engine Tests
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE: Validate MLInsightsEngine components — DescriptiveStatistics,
//  configuration thresholds, model status enum, and error types.
//
//  NOTE: Anomaly detection and pattern recognition methods require SwiftData
//  Transaction objects. Those are covered via integration tests / UI tests.
//  These unit tests focus on the pure-logic and statistical components.
//
//  COVERS:
//  - DescriptiveStatistics (mean, stdDev, median)
//  - MLModelStatus equality and states
//  - MLInsightsError descriptions
//  - Configuration constant validation
//  - SubscriptionTier.hasMLInsights gating
//

import XCTest
@testable import FLO

final class FLOMLInsightsTests: XCTestCase {

    // MARK: - Precision

    let statsPrecision: Double = 0.001
}

// MARK: - DescriptiveStatistics

extension FLOMLInsightsTests {

    /// Test: Mean calculation
    func testStats_Mean() {
        let stats = DescriptiveStatistics(values: [10, 20, 30, 40, 50])
        XCTAssertEqual(stats.mean, 30.0, accuracy: statsPrecision, "Mean of [10,20,30,40,50] = 30")
    }

    /// Test: Median of odd count
    func testStats_MedianOdd() {
        let stats = DescriptiveStatistics(values: [10, 20, 30, 40, 50])
        XCTAssertEqual(stats.median, 30.0, accuracy: statsPrecision, "Median of 5 values = middle value")
    }

    /// Test: Median of even count
    func testStats_MedianEven() {
        let stats = DescriptiveStatistics(values: [10, 20, 30, 40])
        XCTAssertEqual(stats.median, 25.0, accuracy: statsPrecision, "Median of 4 values = average of 2 middle")
    }

    /// Test: Standard deviation
    func testStats_StdDev() {
        let stats = DescriptiveStatistics(values: [2, 4, 4, 4, 5, 5, 7, 9])
        // Population variance = 4.0, sample variance = 4.571, sample stddev = 2.138
        XCTAssertEqual(stats.stdDev, 2.138, accuracy: 0.01, "Sample standard deviation")
    }

    /// Test: StdDev of identical values is zero
    func testStats_StdDev_AllSame() {
        let stats = DescriptiveStatistics(values: [42, 42, 42, 42])
        XCTAssertEqual(stats.stdDev, 0.0, accuracy: statsPrecision, "All identical = zero stddev")
    }

    /// Test: Single value
    func testStats_SingleValue() {
        let stats = DescriptiveStatistics(values: [100])
        XCTAssertEqual(stats.mean, 100.0, accuracy: statsPrecision)
        XCTAssertEqual(stats.median, 100.0, accuracy: statsPrecision)
        XCTAssertEqual(stats.stdDev, 0.0, accuracy: statsPrecision, "Single value = zero stddev")
        XCTAssertEqual(stats.count, 1)
    }

    /// Test: Empty values
    func testStats_Empty() {
        let stats = DescriptiveStatistics(values: [])
        XCTAssertEqual(stats.mean, 0.0, accuracy: statsPrecision)
        XCTAssertEqual(stats.median, 0.0, accuracy: statsPrecision)
        XCTAssertEqual(stats.stdDev, 0.0, accuracy: statsPrecision)
        XCTAssertEqual(stats.count, 0)
    }

    /// Test: Two values
    func testStats_TwoValues() {
        let stats = DescriptiveStatistics(values: [10, 20])
        XCTAssertEqual(stats.mean, 15.0, accuracy: statsPrecision)
        XCTAssertEqual(stats.median, 15.0, accuracy: statsPrecision, "Even count: average of both")
        XCTAssertGreaterThan(stats.stdDev, 0, "Two different values = nonzero stddev")
    }

    /// Test: Large dataset statistics
    func testStats_LargeDataset() {
        let values = (1...1000).map { Double($0) }
        let stats = DescriptiveStatistics(values: values)

        XCTAssertEqual(stats.mean, 500.5, accuracy: 0.01)
        XCTAssertEqual(stats.median, 500.5, accuracy: 0.01)
        XCTAssertEqual(stats.count, 1000)
        XCTAssertGreaterThan(stats.stdDev, 200, "Wide range = large stddev")
    }

    /// Test: Unsorted input is handled correctly
    func testStats_UnsortedInput() {
        let stats = DescriptiveStatistics(values: [50, 10, 40, 20, 30])
        XCTAssertEqual(stats.mean, 30.0, accuracy: statsPrecision)
        XCTAssertEqual(stats.median, 30.0, accuracy: statsPrecision, "Should sort internally")
    }

    /// Test: Z-score anomaly detection math
    @MainActor
    func testStats_ZScoreDetection() {
        // Extract @MainActor-isolated value to avoid autoclosure warnings
        let threshold = MLInsightsEngine.anomalyZScoreThreshold

        let values: [Double] = [100, 105, 95, 102, 98, 100, 97, 103, 101, 99]
        let stats = DescriptiveStatistics(values: values)

        // A value of $200 should be flagged as anomalous
        let anomalousValue: Double = 200
        let zScore = stats.stdDev > 0 ? (anomalousValue - stats.mean) / stats.stdDev : 0

        XCTAssertGreaterThan(zScore, threshold,
            "Value $200 in a ~$100 dataset should exceed 2.5σ threshold")

        // A normal value should NOT be flagged
        let normalValue: Double = 105
        let normalZ = stats.stdDev > 0 ? (normalValue - stats.mean) / stats.stdDev : 0

        XCTAssertLessThan(normalZ, threshold,
            "$105 in a ~$100 dataset should be within normal range")
    }
}

// MARK: - MLModelStatus

extension FLOMLInsightsTests {

    /// Test: Status equality
    func testModelStatus_Equality() {
        let date = Date()
        XCTAssertEqual(MLModelStatus.notTrained, MLModelStatus.notTrained)
        XCTAssertEqual(MLModelStatus.training, MLModelStatus.training)
        XCTAssertEqual(MLModelStatus.ready(lastTrained: date), MLModelStatus.ready(lastTrained: date))
        XCTAssertEqual(
            MLModelStatus.insufficientData(required: 30, current: 10),
            MLModelStatus.insufficientData(required: 30, current: 10)
        )
        XCTAssertEqual(MLModelStatus.error("fail"), MLModelStatus.error("fail"))
    }

    /// Test: Status inequality
    func testModelStatus_Inequality() {
        XCTAssertNotEqual(MLModelStatus.notTrained, MLModelStatus.training)
        XCTAssertNotEqual(MLModelStatus.error("a"), MLModelStatus.error("b"))
        XCTAssertNotEqual(
            MLModelStatus.insufficientData(required: 30, current: 10),
            MLModelStatus.insufficientData(required: 30, current: 20)
        )
    }
}

// MARK: - MLInsightsError

extension FLOMLInsightsTests {

    /// Test: Error descriptions are non-empty
    func testError_HasDescriptions() {
        let errors: [MLInsightsError] = [
            .engineDeallocated,
            .insufficientRows(3),
            .modelNotTrained,
            .predictionFailed("test")
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error \(error) should have a description")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Error description should not be empty")
        }
    }

    /// Test: insufficientRows includes count
    func testError_InsufficientRowsMessage() {
        let error = MLInsightsError.insufficientRows(3)
        XCTAssertTrue(error.errorDescription!.contains("3"), "Should mention the row count")
    }
}

// MARK: - Configuration Constants

extension FLOMLInsightsTests {

    /// Test: Thresholds are sensible
    @MainActor
    func testConfig_ThresholdsAreSensible() {
        // Extract @MainActor-isolated values to avoid autoclosure warnings
        let minMonths = MLInsightsEngine.minimumMonthsForPrediction
        let minTx = MLInsightsEngine.minimumTransactionsForAnalysis
        let zThreshold = MLInsightsEngine.anomalyZScoreThreshold
        let cooldown = MLInsightsEngine.trainingCooldown

        XCTAssertGreaterThanOrEqual(
            minMonths, 2,
            "Need at least 2 months for meaningful prediction"
        )
        XCTAssertGreaterThanOrEqual(
            minTx, 10,
            "Need reasonable transaction count"
        )
        XCTAssertGreaterThan(
            zThreshold, 2.0,
            "Z-score threshold should be > 2σ to avoid false positives"
        )
        XCTAssertLessThan(
            zThreshold, 4.0,
            "Z-score threshold should be < 4σ to catch real anomalies"
        )
        XCTAssertEqual(
            cooldown, 86400,
            "Training cooldown should be 24 hours"
        )
    }
}

// MARK: - Subscription Tier Gating

extension FLOMLInsightsTests {

    /// Test: hasMLInsights requires Premium or higher
    func testSubscription_MLInsightsGating() {
        XCTAssertFalse(SubscriptionTier.free.hasMLInsights, "Free should NOT have ML insights")
        XCTAssertTrue(SubscriptionTier.premium.hasMLInsights, "Premium SHOULD have ML insights")
        XCTAssertTrue(SubscriptionTier.pro.hasMLInsights, "Pro SHOULD have ML insights")
    }
}

// MARK: - InsightType.prediction

extension FLOMLInsightsTests {

    /// Test: prediction case exists and has icon/color
    func testInsightType_PredictionExists() {
        let type = InsightType.prediction

        XCTAssertFalse(type.defaultIcon.isEmpty, "Prediction type should have an icon")
        // Verify it doesn't crash and returns a valid color
        let _ = type.defaultColor
    }
}
