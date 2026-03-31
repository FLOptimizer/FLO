//  RecurringDetectionView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - Accessibility Audit Fixes
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE:
//  Displays detected recurring transaction patterns with accept/dismiss actions.
//  Also provides DetectedPatternsSection for embedding in RecurringListView.
//
//  CHANGES v1.1 - Accessibility Audit:
//  ✅ FIXED: DetectedPatternRow buttons hidden by .combine — added custom accessibility actions
//  ✅ FIXED: Loading ProgressView missing .updatesFrequently trait
//
//  FEATURES v1.0:
//  ✅ Full list view of detected patterns with confidence badges
//  ✅ Accept action creates RecurringTransaction from pattern
//  ✅ Dismiss action hides pattern permanently
//  ✅ Embeddable DetectedPatternsSection for RecurringListView (top 3 + See All)
//  ✅ VoiceOver accessibility support
//  ✅ Dynamic Type support with lineLimit + minimumScaleFactor
//  ✅ Haptic feedback via HapticService
//  ✅ FLOAnimation stagger entrance

import SwiftUI
import FLODesignSystem
import SwiftData

// MARK: - Detected Patterns Section (Embeddable)

/// Embeddable section showing top 3 detected patterns for RecurringListView.
struct DetectedPatternsSection: View {
    @Environment(\.modelContext) private var context
    @ObservedObject private var detectionService = RecurringDetectionService.shared
    @State private var viewAppeared = false

    var body: some View {
        if !detectionService.detectedPatterns.isEmpty {
            Section {
                ForEach(Array(detectionService.detectedPatterns.prefix(3).enumerated()), id: \.element.id) { index, pattern in
                    DetectedPatternRow(pattern: pattern) {
                        acceptPattern(pattern)
                    } onDismiss: {
                        dismissPattern(pattern)
                    }
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(x: viewAppeared ? 0 : 20)
                    .animation(
                        FLOAnimation.standard.delay(Double(index) * 0.05),
                        value: viewAppeared
                    )
                }

                if detectionService.detectedPatterns.count > 3 {
                    NavigationLink {
                        RecurringDetectionView()
                    } label: {
                        HStack {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(Color.brandPrimary)
                                .accessibilityHidden(true)
                            Text("See All Detected (\(detectionService.detectedPatterns.count))")
                                .foregroundStyle(Color.brandPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    .accessibilityLabel("See all \(detectionService.detectedPatterns.count) detected recurring patterns")
                }
            } header: {
                HStack {
                    Label("Detected", systemImage: "wand.and.stars")
                    Spacer()
                    Text("\(detectionService.detectedPatterns.count)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.brandPrimary.opacity(0.15))
                        .cornerRadius(8)
                        .foregroundStyle(Color.brandPrimary)
                }
            }
            .onAppear {
                withAnimation(FLOAnimation.standard) {
                    viewAppeared = true
                }
            }
        }
    }

    private func acceptPattern(_ pattern: DetectedRecurringPattern) {
        HapticService.play(.success)
        _ = withAnimation(FLOAnimation.quick) {
            detectionService.acceptPattern(pattern, in: context)
        }
        AccessibilityAnnouncement.announce("\(pattern.merchantName) added as recurring \(pattern.detectedFrequency.displayName) transaction")
    }

    private func dismissPattern(_ pattern: DetectedRecurringPattern) {
        HapticService.play(.light)
        withAnimation(FLOAnimation.quick) {
            detectionService.dismissPattern(pattern)
        }
        AccessibilityAnnouncement.announce("\(pattern.merchantName) dismissed")
    }
}

// MARK: - Full Detection View

/// Full-screen view showing all detected recurring patterns.
struct RecurringDetectionView: View {
    @Environment(\.modelContext) private var context
    @ObservedObject private var detectionService = RecurringDetectionService.shared
    @State private var viewAppeared = false

    var body: some View {
        List {
            if detectionService.isAnalyzing {
                Section {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Analyzing transactions...")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.updatesFrequently)
                }
            }

            if !detectionService.detectedPatterns.isEmpty {
                Section {
                    ForEach(Array(detectionService.detectedPatterns.enumerated()), id: \.element.id) { index, pattern in
                        DetectedPatternRow(pattern: pattern) {
                            acceptPattern(pattern)
                        } onDismiss: {
                            dismissPattern(pattern)
                        }
                        .opacity(viewAppeared ? 1 : 0.001)
                        .offset(x: viewAppeared ? 0 : 20)
                        .animation(
                            FLOAnimation.standard.delay(Double(index) * 0.05),
                            value: viewAppeared
                        )
                    }
                } header: {
                    Text("We found \(detectionService.detectedPatterns.count) recurring pattern\(detectionService.detectedPatterns.count == 1 ? "" : "s")")
                } footer: {
                    Text("Patterns are detected from your transaction history. Tap the checkmark to add as a recurring transaction, or X to dismiss.")
                }
            }

            if !detectionService.isAnalyzing && detectionService.detectedPatterns.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Patterns Detected",
                        systemImage: "wand.and.stars",
                        description: Text("FLO analyzes your transactions to find recurring bills and income. Keep adding transactions and we'll detect patterns automatically.")
                    )
                }
            }

            if detectionService.lastAnalysisDate != nil {
                Section {
                    HStack {
                        Text("Last analyzed")
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let date = detectionService.lastAnalysisDate {
                            Text(date, style: .relative)
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }

                    Button {
                        detectionService.clearDismissedPatterns()
                        HapticService.play(.medium)
                        AccessibilityAnnouncement.announce("Dismissed patterns cleared. Analysis will include previously dismissed merchants.")
                    } label: {
                        Label("Reset Dismissed Patterns", systemImage: "arrow.counterclockwise")
                    }
                    .accessibilityHint("Previously dismissed merchants will appear again in future analysis")
                }
            }
        }
        .navigationTitle("Detected Patterns")
        .onAppear {
            withAnimation(FLOAnimation.standard) {
                viewAppeared = true
            }
            AccessibilityAnnouncement.screenChanged("Detected recurring patterns")
        }
    }

    private func acceptPattern(_ pattern: DetectedRecurringPattern) {
        HapticService.play(.success)
        _ = withAnimation(FLOAnimation.quick) {
            detectionService.acceptPattern(pattern, in: context)
        }
        AccessibilityAnnouncement.announce("\(pattern.merchantName) added as recurring \(pattern.detectedFrequency.displayName) transaction")
    }

    private func dismissPattern(_ pattern: DetectedRecurringPattern) {
        HapticService.play(.light)
        withAnimation(FLOAnimation.quick) {
            detectionService.dismissPattern(pattern)
        }
        AccessibilityAnnouncement.announce("\(pattern.merchantName) dismissed")
    }
}

// MARK: - Detected Pattern Row

/// A single detected pattern row with accept/dismiss buttons.
struct DetectedPatternRow: View {
    let pattern: DetectedRecurringPattern
    let onAccept: () -> Void
    let onDismiss: () -> Void

    @State private var iconAppeared = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            iconView

            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(pattern.merchantName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                HStack(spacing: 6) {
                    Text(pattern.detectedFrequency.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text("·")
                        .foregroundStyle(.secondary)

                    Text("\(pattern.transactionCount) matches")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                // Confidence badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(confidenceColor)
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)
                    Text("\(pattern.confidenceLabel) confidence")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    if let nextDate = pattern.estimatedNextDate {
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text("Next: \(nextDate, style: .date)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }

            Spacer()

            // Amount
            VStack(alignment: .trailing, spacing: 4) {
                Text(pattern.formattedAmount)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(pattern.isIncome ? Color.incomeGreen : Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                // Action buttons
                HStack(spacing: 8) {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss \(pattern.merchantName)")
                    .accessibilityHint("Won't suggest this pattern again")

                    Button {
                        onAccept()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.brandPrimary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add \(pattern.merchantName) as recurring")
                    .accessibilityHint("Creates a \(pattern.detectedFrequency.displayName) recurring transaction for \(pattern.formattedAmount)")
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAction(named: "Add as recurring") {
            onAccept()
        }
        .accessibilityAction(named: "Dismiss") {
            onDismiss()
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                iconAppeared = true
            }
        }
    }

    private var iconView: some View {
        Image(systemName: "wand.and.stars")
            .font(.title3)
            .foregroundStyle(Color.brandPrimary)
            .frame(width: 40, height: 40)
            .background(Color.brandPrimary.opacity(0.1))
            .cornerRadius(10)
            .scaleEffect(iconAppeared ? 1 : 0.5)
            .accessibilityHidden(true)
    }

    private var confidenceColor: Color {
        switch pattern.confidenceLabel {
        case "High": return .green
        case "Medium": return .orange
        default: return .yellow
        }
    }

    private var accessibilityLabel: String {
        let type = pattern.isIncome ? "income" : "expense"
        return "\(pattern.merchantName), detected \(pattern.detectedFrequency.displayName) \(type) of \(pattern.formattedAmount), \(pattern.confidenceLabel) confidence, \(pattern.transactionCount) matches"
    }
}
