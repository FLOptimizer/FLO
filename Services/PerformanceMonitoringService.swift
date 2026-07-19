//  PerformanceMonitoringService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - Catalyst memory thresholds · Performance Profiling & Instrumentation
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE:
//  Comprehensive performance monitoring for Instruments profiling,
//  real-world metrics collection, and explicit performance budgets.
//
//  FEATURES v1.0:
//  ✅ os_signpost instrumentation for Instruments Time Profiler & Points of Interest
//  ✅ MetricKit integration for App Store-level performance data
//  ✅ Memory footprint monitoring with budget thresholds
//  ✅ CADisplayLink frame rate tracking with hitch detection
//  ✅ Explicit performance budgets per Apple HIG
//  ✅ View render timing modifier
//  ✅ Zero overhead in release when Instruments is not attached (os_signpost design)
//
//  INSTRUMENTS WORKFLOW:
//  1. Profile with Instruments → os_signpost category "FLO.Launch" shows cold start intervals
//  2. "FLO.DataOperation" shows SwiftData queries and service calls
//  3. "FLO.Rendering" shows view render times
//  4. "FLO.Navigation" shows tab/screen transitions
//  5. MetricKit delivers 24-hour aggregate metrics from real users
//

import SwiftUI
import os
import MetricKit
import QuartzCore

// MARK: - Performance Budgets

/// Explicit performance budgets for FLO
///
/// These thresholds define acceptable performance per Apple Human Interface Guidelines.
/// Violations are logged as warnings; critical violations as errors.
///
/// Measure with Instruments → Time Profiler and MetricKit aggregates.
enum FLOPerformanceBudget {
    /// Cold start must complete in under 1000ms (app launch → first interactive frame)
    static let coldStartMs: Double = 1000

    /// Warm resume (returning from background) under 500ms
    static let warmResumeMs: Double = 500

    /// Dashboard should render first meaningful content within 200ms of appearing
    static let dashboardFirstContentMs: Double = 200

    /// Target 60fps — any frame over 16.67ms is a hitch
    static let frameDeadlineMs: Double = 16.67

    /// Memory footprint warning threshold
    /// macOS apps with charts/graphics commonly use 200-300MB; iOS is more constrained.
    #if os(macOS) || targetEnvironment(macCatalyst)
    static let memoryWarningMB: Double = 200
    static let memoryCriticalMB: Double = 400
    #else
    static let memoryWarningMB: Double = 150
    static let memoryCriticalMB: Double = 300
    #endif

    /// SwiftData query should complete within 100ms
    static let dataQueryMs: Double = 100
}

// MARK: - Performance Monitor

/// Central performance monitoring service for FLO.
///
/// Provides four measurement systems:
/// 1. **os_signpost** — Zero-overhead Instruments profiling (intervals & points of interest)
/// 2. **MetricKit** — 24-hour aggregate metrics from real devices
/// 3. **Memory tracking** — Periodic footprint checks against budgets
/// 4. **Frame rate** — CADisplayLink hitch detection for scroll performance
///
/// Usage:
/// ```swift
/// // In FLOApp.swift:
/// PerformanceMonitor.shared.beginLaunch()
/// PerformanceMonitor.shared.launchCheckpoint("ModelContainer created")
/// PerformanceMonitor.shared.endLaunch()
///
/// // Signpost any operation:
/// PerformanceMonitor.shared.beginInterval("FetchTransactions", category: .data)
/// // ... work ...
/// PerformanceMonitor.shared.endInterval("FetchTransactions", category: .data, state: state)
/// ```
@MainActor
final class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()

    // MARK: - Logger

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.finchandpoppy.flo",
        category: "Performance"
    )

    // MARK: - Signposters (for Instruments)

    /// Signpost categories visible in Instruments → Points of Interest
    enum SignpostCategory {
        case launch
        case navigation
        case data
        case rendering

        var signposter: OSSignposter {
            let subsystem = Bundle.main.bundleIdentifier ?? "com.finchandpoppy.flo"
            switch self {
            case .launch:     return OSSignposter(subsystem: subsystem, category: "FLO.Launch")
            case .navigation: return OSSignposter(subsystem: subsystem, category: "FLO.Navigation")
            case .data:       return OSSignposter(subsystem: subsystem, category: "FLO.DataOperation")
            case .rendering:  return OSSignposter(subsystem: subsystem, category: "FLO.Rendering")
            }
        }
    }

    // Cached signposters (creating OSSignposter is lightweight but let's reuse)
    private let launchSignposter: OSSignposter
    private let navigationSignposter: OSSignposter
    private let dataSignposter: OSSignposter
    private let renderSignposter: OSSignposter

    // MARK: - Launch Tracking

    /// Process start time — captured as early as possible
    nonisolated static let processStart = CFAbsoluteTimeGetCurrent()

    private var launchState: OSSignpostIntervalState?

    // MARK: - Frame Rate Tracking

    #if canImport(UIKit)
    private var displayLink: CADisplayLink?
    #endif
    private let frameTracker = FrameRateTracker()

    // MARK: - Memory Tracking

    @Published private(set) var currentMemoryMB: Double = 0
    private var memoryTimer: Timer?

    // MARK: - MetricKit

    private let metricSubscriber = FLOMetricSubscriber()

    // MARK: - Init

    private init() {
        let subsystem = Bundle.main.bundleIdentifier ?? "com.finchandpoppy.flo"
        self.launchSignposter = OSSignposter(subsystem: subsystem, category: "FLO.Launch")
        self.navigationSignposter = OSSignposter(subsystem: subsystem, category: "FLO.Navigation")
        self.dataSignposter = OSSignposter(subsystem: subsystem, category: "FLO.DataOperation")
        self.renderSignposter = OSSignposter(subsystem: subsystem, category: "FLO.Rendering")
    }

    // MARK: - Signposter Access

    /// Get the signposter for a given category
    func signposter(for category: SignpostCategory) -> OSSignposter {
        switch category {
        case .launch:     return launchSignposter
        case .navigation: return navigationSignposter
        case .data:       return dataSignposter
        case .rendering:  return renderSignposter
        }
    }

    // MARK: - Launch Profiling

    /// Start the cold launch signpost interval.
    /// Call this as early as possible in FLOApp.init().
    func beginLaunch() {
        launchState = launchSignposter.beginInterval("ColdStart")
        logger.info("🚀 Launch signpost started")
    }

    /// Emit a named checkpoint event within the launch interval.
    /// These appear as points of interest in Instruments.
    func launchCheckpoint(_ name: StaticString) {
        launchSignposter.emitEvent(name)

        let elapsed = (CFAbsoluteTimeGetCurrent() - Self.processStart) * 1000
        logger.info("⏱️ [\(String(format: "%6.1f", elapsed))ms] Launch checkpoint")
    }

    /// End the cold launch signpost interval and evaluate against budget.
    /// Call this after the first meaningful frame is on screen.
    func endLaunch() {
        if let state = launchState {
            launchSignposter.endInterval("ColdStart", state)
            launchState = nil
        }

        let totalMs = (CFAbsoluteTimeGetCurrent() - Self.processStart) * 1000

        if totalMs < FLOPerformanceBudget.coldStartMs {
            logger.info("✅ Cold start: \(String(format: "%.0f", totalMs))ms (budget: \(FLOPerformanceBudget.coldStartMs, format: .fixed(precision: 0))ms)")
        } else {
            logger.warning("⚠️ Cold start: \(String(format: "%.0f", totalMs))ms EXCEEDS budget of \(FLOPerformanceBudget.coldStartMs, format: .fixed(precision: 0))ms")
        }
    }

    // MARK: - General Signpost Intervals

    /// Begin a named signpost interval. Returns state to pass to `endInterval`.
    ///
    /// ```swift
    /// let state = monitor.beginInterval("LoadAccounts", category: .data)
    /// let accounts = try await fetchAccounts()
    /// monitor.endInterval("LoadAccounts", category: .data, state: state)
    /// ```
    func beginInterval(_ name: StaticString, category: SignpostCategory = .data) -> OSSignpostIntervalState {
        signposter(for: category).beginInterval(name)
    }

    /// End a named signpost interval.
    func endInterval(_ name: StaticString, category: SignpostCategory = .data, state: OSSignpostIntervalState) {
        signposter(for: category).endInterval(name, state)
    }

    /// Emit a point-of-interest event (appears in Instruments timeline).
    func emitEvent(_ name: StaticString, category: SignpostCategory = .data) {
        signposter(for: category).emitEvent(name)
    }

    // MARK: - Frame Rate Monitoring

    /// Start monitoring frame rate using CADisplayLink.
    /// Use during scroll performance testing or continuous monitoring.
    func startFrameRateMonitoring() {
        #if canImport(UIKit)
        guard displayLink == nil else { return }

        frameTracker.reset()
        displayLink = CADisplayLink(target: frameTracker, selector: #selector(FrameRateTracker.tick(_:)))
        displayLink?.add(to: .main, forMode: .common)

        logger.debug("📊 Frame rate monitoring started")
        #endif
    }

    /// Stop monitoring and return a frame rate report.
    @discardableResult
    func stopFrameRateMonitoring() -> FrameRateReport {
        #if canImport(UIKit)
        displayLink?.invalidate()
        displayLink = nil
        #endif

        let report = FrameRateReport(
            averageFPS: frameTracker.averageFPS,
            hitchCount: frameTracker.hitchCount,
            totalFrames: frameTracker.frameCount,
            monitoringDuration: frameTracker.totalDuration
        )

        if report.totalFrames > 0 {
            if report.hitchRatio < 0.01 {
                logger.info("✅ Frame rate: \(report.summary)")
            } else {
                logger.warning("⚠️ Frame rate: \(report.summary)")
            }
        }

        return report
    }

    // MARK: - Memory Monitoring

    /// Start periodic memory footprint checks.
    /// - Parameter interval: Check interval in seconds (default: 10s).
    func startMemoryMonitoring(interval: TimeInterval = 10.0) {
        currentMemoryMB = Self.currentMemoryFootprintMB()
        logger.info("🧠 Memory at launch: \(String(format: "%.1f", self.currentMemoryMB))MB")

        memoryTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkMemory()
            }
        }
    }

    /// Stop memory monitoring.
    func stopMemoryMonitoring() {
        memoryTimer?.invalidate()
        memoryTimer = nil
    }

    /// Log current memory footprint once.
    func logMemorySnapshot(_ label: String = "Snapshot") {
        let mb = Self.currentMemoryFootprintMB()
        currentMemoryMB = mb
        logger.info("🧠 Memory [\(label)]: \(String(format: "%.1f", mb))MB")
    }

    private func checkMemory() {
        let mb = Self.currentMemoryFootprintMB()
        currentMemoryMB = mb

        if mb > FLOPerformanceBudget.memoryCriticalMB {
            logger.critical("🔴 Memory CRITICAL: \(String(format: "%.1f", mb))MB exceeds \(FLOPerformanceBudget.memoryCriticalMB, format: .fixed(precision: 0))MB limit")
        } else if mb > FLOPerformanceBudget.memoryWarningMB {
            logger.warning("🟡 Memory WARNING: \(String(format: "%.1f", mb))MB exceeds \(FLOPerformanceBudget.memoryWarningMB, format: .fixed(precision: 0))MB threshold")
        }
    }

    /// Get current physical memory footprint in MB.
    /// Uses `task_vm_info.phys_footprint` — the same metric Xcode's Memory Gauge shows.
    nonisolated static func currentMemoryFootprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size
        )

        let result = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rawPtr in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), rawPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.phys_footprint) / (1024 * 1024)
    }

    // MARK: - MetricKit Registration

    /// Register for MetricKit payloads. Call once in AppDelegate or FLOApp.init().
    /// MetricKit delivers 24-hour aggregate metrics and diagnostic reports.
    func registerMetricKit() {
        MXMetricManager.shared.add(metricSubscriber)
        logger.info("📈 MetricKit subscriber registered")
    }

    /// Unregister MetricKit subscriber.
    func unregisterMetricKit() {
        MXMetricManager.shared.remove(metricSubscriber)
    }
}

// MARK: - Frame Rate Tracker

/// Lightweight CADisplayLink callback target for frame timing.
/// Counts frames and detects hitches (frames exceeding 16.67ms deadline).
private final class FrameRateTracker: NSObject {
    var lastTimestamp: CFTimeInterval = 0
    var frameCount: Int = 0
    var hitchCount: Int = 0
    var totalDuration: CFTimeInterval = 0

    var averageFPS: Double {
        guard totalDuration > 0 else { return 0 }
        return Double(frameCount) / totalDuration
    }

    #if canImport(UIKit)
    @objc func tick(_ link: CADisplayLink) {
        if lastTimestamp > 0 {
            let frameDurationMs = (link.timestamp - lastTimestamp) * 1000
            frameCount += 1
            totalDuration += link.timestamp - lastTimestamp

            // A "hitch" is any frame that exceeds the 60fps deadline
            if frameDurationMs > FLOPerformanceBudget.frameDeadlineMs {
                hitchCount += 1
            }
        }
        lastTimestamp = link.timestamp
    }
    #endif

    func reset() {
        lastTimestamp = 0
        frameCount = 0
        hitchCount = 0
        totalDuration = 0
    }
}

// MARK: - Frame Rate Report

/// Summary of a frame rate monitoring session.
struct FrameRateReport {
    let averageFPS: Double
    let hitchCount: Int
    let totalFrames: Int
    let monitoringDuration: TimeInterval

    /// Ratio of hitched frames (0.0 = perfect, 1.0 = all hitched)
    var hitchRatio: Double {
        guard totalFrames > 0 else { return 0 }
        return Double(hitchCount) / Double(totalFrames)
    }

    var summary: String {
        let fpsStr = String(format: "%.1f", averageFPS)
        let ratioStr = String(format: "%.1f", hitchRatio * 100)
        let durationStr = String(format: "%.1f", monitoringDuration)
        return "\(fpsStr) FPS avg, \(hitchCount) hitches / \(totalFrames) frames (\(ratioStr)%) over \(durationStr)s"
    }
}

// MARK: - MetricKit Subscriber

/// Receives 24-hour aggregate performance metrics and diagnostic reports from MetricKit.
///
/// MetricKit delivers payloads once per day containing:
/// - Launch metrics (time to first draw, resume time)
/// - Responsiveness metrics (hang time histogram)
/// - Memory metrics (peak memory, average suspended memory)
/// - Disk I/O, network transfer, cellular condition
/// - Diagnostic reports (crashes, hangs, CPU exceptions, disk writes)
final class FLOMetricSubscriber: NSObject, MXMetricManagerSubscriber {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.finchandpoppy.flo",
        category: "MetricKit"
    )

    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            logger.info("📈 MetricKit metrics payload received (\(payload.timeStampEnd.formatted()))")

            // Launch performance
            if let launch = payload.applicationLaunchMetrics {
                let firstDraw = launch.histogrammedTimeToFirstDraw
                logger.info("  ⏱️ Time to first draw: \(firstDraw)")

                let resume = launch.histogrammedApplicationResumeTime
                logger.info("  ⏱️ Resume time: \(resume)")
            }

            // App responsiveness (hangs)
            if let responsiveness = payload.applicationResponsivenessMetrics {
                logger.info("  ⏸️ Hang time: \(responsiveness.histogrammedApplicationHangTime)")
            }

            // Memory
            if let memory = payload.memoryMetrics {
                logger.info("  🧠 Peak memory: \(memory.peakMemoryUsage)")
            }

            #if DEBUG
            // Save full JSON for offline analysis in debug builds
            let jsonData = payload.jsonRepresentation()
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                logger.debug("📊 MetricKit full payload: \(jsonString)")
            }
            #endif
        }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            logger.warning("⚠️ MetricKit diagnostic report received")

            if let crashes = payload.crashDiagnostics, !crashes.isEmpty {
                logger.critical("  💥 \(crashes.count) crash diagnostic(s)")
            }
            if let hangs = payload.hangDiagnostics, !hangs.isEmpty {
                logger.warning("  ⏸️ \(hangs.count) hang diagnostic(s)")
            }
            if let cpu = payload.cpuExceptionDiagnostics, !cpu.isEmpty {
                logger.warning("  🔥 \(cpu.count) CPU exception diagnostic(s)")
            }
            if let disk = payload.diskWriteExceptionDiagnostics, !disk.isEmpty {
                logger.warning("  💾 \(disk.count) disk write exception diagnostic(s)")
            }

            #if DEBUG
            let diagData = payload.jsonRepresentation()
            if let diagString = String(data: diagData, encoding: .utf8) {
                logger.debug("📊 Diagnostic payload: \(diagString)")
            }
            #endif
        }
    }
}

// MARK: - Render Timing View Modifier

/// Measures time from view appearance to first render and logs against a performance budget.
///
/// Usage:
/// ```swift
/// DashboardView()
///     .measureRenderTime("Dashboard")
/// ```
struct FLORenderTimingModifier: ViewModifier {
    let viewName: String
    let budgetMs: Double

    @State private var appearTime: CFAbsoluteTime = 0

    func body(content: Content) -> some View {
        content
            .onAppear {
                appearTime = CFAbsoluteTimeGetCurrent()
            }
            .task {
                // Wait one run-loop tick for the first frame to commit
                try? await Task.sleep(for: .milliseconds(1))
                guard appearTime > 0 else { return }

                let renderMs = (CFAbsoluteTimeGetCurrent() - appearTime) * 1000
                let signposter = PerformanceMonitor.shared.signposter(for: .rendering)
                signposter.emitEvent("ViewRendered")

                let logger = Logger(
                    subsystem: Bundle.main.bundleIdentifier ?? "com.finchandpoppy.flo",
                    category: "Rendering"
                )

                if renderMs < budgetMs {
                    logger.info("✅ \(viewName) rendered in \(String(format: "%.1f", renderMs))ms (budget: \(budgetMs, format: .fixed(precision: 0))ms)")
                } else {
                    logger.warning("⚠️ \(viewName) took \(String(format: "%.1f", renderMs))ms — exceeds \(budgetMs, format: .fixed(precision: 0))ms budget")
                }
            }
    }
}

extension View {
    /// Measure render time of this view and log against a performance budget.
    ///
    /// - Parameters:
    ///   - viewName: Human-readable name for log messages (e.g., "Dashboard", "TransactionList").
    ///   - budget: Maximum acceptable render time in milliseconds. Defaults to `FLOPerformanceBudget.dashboardFirstContentMs`.
    func measureRenderTime(
        _ viewName: String,
        budget: Double = FLOPerformanceBudget.dashboardFirstContentMs
    ) -> some View {
        modifier(FLORenderTimingModifier(viewName: viewName, budgetMs: budget))
    }
}

// MARK: - Preview

#Preview("Performance Budgets") {
    List {
        Section("Performance Budgets") {
            LabeledContent("Cold Start", value: "\(Int(FLOPerformanceBudget.coldStartMs))ms")
            LabeledContent("Warm Resume", value: "\(Int(FLOPerformanceBudget.warmResumeMs))ms")
            LabeledContent("Dashboard Render", value: "\(Int(FLOPerformanceBudget.dashboardFirstContentMs))ms")
            LabeledContent("Frame Deadline", value: "\(String(format: "%.2f", FLOPerformanceBudget.frameDeadlineMs))ms")
            LabeledContent("Data Query", value: "\(Int(FLOPerformanceBudget.dataQueryMs))ms")
        }

        Section("Memory Budgets") {
            LabeledContent("Warning", value: "\(Int(FLOPerformanceBudget.memoryWarningMB))MB")
            LabeledContent("Critical", value: "\(Int(FLOPerformanceBudget.memoryCriticalMB))MB")
        }

        Section("Current") {
            LabeledContent("Memory", value: "\(String(format: "%.1f", PerformanceMonitor.currentMemoryFootprintMB()))MB")
        }
    }
}
