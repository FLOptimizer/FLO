//  UsageWarningBanner.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.2 - Dynamic Type verification: lineLimit + minimumScaleFactor on all text
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.2 - Dynamic Type Verification:
//  ✅ FIXED: Full banner warning message text - lineLimit(2) + minimumScaleFactor(0.7)
//  ✅ FIXED: Full banner upgrade caption text - lineLimit(1) + minimumScaleFactor(0.7)
//  ✅ FIXED: Full banner upgrade button text - lineLimit(1) + minimumScaleFactor(0.8)
//  ✅ FIXED: Full banner progress bar upgrade button text - lineLimit(1) + minimumScaleFactor(0.8)
//  ✅ FIXED: Compact banner message text - lineLimit(1) + minimumScaleFactor(0.7)
//  ✅ FIXED: Compact banner upgrade button text - lineLimit(1) + minimumScaleFactor(0.8)
//  ✅ FIXED: LimitReachedOverlay title text - lineLimit(2) + minimumScaleFactor(0.7)
//  ✅ FIXED: LimitReachedOverlay message text - lineLimit(3) + minimumScaleFactor(0.7)
//  ✅ FIXED: LimitReachedOverlay usage count text - lineLimit(1) + minimumScaleFactor(0.5)
//  ✅ FIXED: LimitReachedOverlay "of" connector text - lineLimit(1) + minimumScaleFactor(0.8)
//  ✅ FIXED: LimitReachedOverlay benefits header text - lineLimit(1) + minimumScaleFactor(0.7)
//  ✅ FIXED: LimitReachedOverlay benefit row text - lineLimit(1) + minimumScaleFactor(0.7)
//  ✅ FIXED: LimitReachedOverlay upgrade button text - lineLimit(1) + minimumScaleFactor(0.7)
//  ✅ FIXED: LimitReachedOverlay dismiss button text - lineLimit(1) + minimumScaleFactor(0.8)
//  ✅ FIXED: UsageLimitIndicator usage text - lineLimit(1) + minimumScaleFactor(0.7)
//  ✅ FIXED: UsageLimitIndicator upgrade button text - lineLimit(1) + minimumScaleFactor(0.8)
//  ✅ FIXED: UsageLimitIndicator unlimited text - lineLimit(1) + minimumScaleFactor(0.7)
//  ✅ FIXED: MonthlyUsageIndicator usage text - lineLimit(1) + minimumScaleFactor(0.7)
//  ✅ FIXED: MonthlyUsageIndicator upgrade button text - lineLimit(1) + minimumScaleFactor(0.8)
//  ✅ FIXED: MonthlyUsageIndicator reset days text - lineLimit(1) + minimumScaleFactor(0.7)
//  ✅ FIXED: MonthlyUsageIndicator unlimited text - lineLimit(1) + minimumScaleFactor(0.7)
//
//  PURPOSE:
//  Reusable SwiftUI component that displays usage warnings and upgrade prompts.
//  Used in AddTransactionView, CreateInvoiceView, FreeTierReceiptView, etc.
//
//  WARNING LEVELS:
//  - Warning (80-89%): Informational yellow/orange banner
//  - Critical (90-99%): Prominent amber/red banner
//  - Blocked (100%): Red banner with disabled action + upgrade CTA
//
//  USAGE:
//  UsageWarningBanner(
//      warning: usageLimitService.getUsageWarning(for: .transactions, tier: tier),
//      showingSubscription: $showingSubscription
//  )
//

import SwiftUI

// MARK: - Usage Warning Banner

struct UsageWarningBanner: View {
    let warning: UsageWarning?
    @Binding var showingSubscription: Bool
    
    /// Optional: compact mode for inline display
    var isCompact: Bool = false
    
    var body: some View {
        if let warning = warning {
            bannerContent(for: warning)
        }
    }
    
    @ViewBuilder
    private func bannerContent(for warning: UsageWarning) -> some View {
        if isCompact {
            compactBanner(for: warning)
        } else {
            fullBanner(for: warning)
        }
    }
    
    // MARK: - Full Banner (Form/Section Header)
    
    private func fullBanner(for warning: UsageWarning) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: warning.level.icon)
                    .font(.title3)
                    .foregroundStyle(warningColor(for: warning.level))
                
                // Message
                VStack(alignment: .leading, spacing: 2) {
                    Text(warning.message)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.primary)
                    
                    if warning.level != .blocked {
                        Text(warning.upgradeMessage)
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Upgrade button (always show for blocked, optional for others)
                if warning.level == .blocked {
                    upgradeButton
                }
            }
            
            // Progress bar for non-blocked states
            if warning.level != .blocked {
                HStack(spacing: 12) {
                    progressBar(current: warning.current, limit: warning.limit, level: warning.level)
                    
                    Button {
                        HapticService.play(.medium)
                        showingSubscription = true
                    } label: {
                        Text("Upgrade")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.brandPrimary)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor(for: warning.level))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor(for: warning.level), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(fullBannerAccessibilityLabel(for: warning))
        .accessibilityHint(warning.level == .blocked ? "Double tap to view upgrade options" : "Double tap to upgrade")
        .accessibilityAddTraits(.isButton)
        .onTapGesture {
            HapticService.play(.medium)
            showingSubscription = true
        }
    }
    
    // MARK: - Compact Banner (Inline)
    
    private func compactBanner(for warning: UsageWarning) -> some View {
        HStack(spacing: 8) {
            Image(systemName: warning.level.icon)
                .font(.caption)
                .foregroundStyle(warningColor(for: warning.level))
            
            Text(warning.message)
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            if warning.level == .blocked {
                Button("Upgrade") {
                    HapticService.play(.medium)
                    showingSubscription = true
                }
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(Color.brandPrimaryText)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(backgroundColor(for: warning.level))
        .cornerRadius(8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(warning.level == .blocked ? "Limit reached" : "Usage warning"). \(warning.message)")
        .accessibilityHint(warning.level == .blocked ? "Double tap to view upgrade options" : "")
    }
    
    // MARK: - Progress Bar
    
    private func progressBar(current: Int, limit: Int, level: UsageWarning.Level) -> some View {
        GeometryReader { geometry in
            let progress = min(1.0, Double(current) / Double(limit))
            let progressWidth = geometry.size.width * progress
            
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                
                // Progress
                RoundedRectangle(cornerRadius: 4)
                    .fill(warningColor(for: level))
                    .frame(width: progressWidth)
            }
        }
        .frame(height: 6)
    }
    
    // MARK: - Upgrade Button
    
    private var upgradeButton: some View {
        Button {
            HapticService.play(.medium)
            showingSubscription = true
        } label: {
            Text("Upgrade")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [Color.brandPrimary, Color.brandPrimaryDark],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
        }
    }
    
    // MARK: - Accessibility
    
    private func fullBannerAccessibilityLabel(for warning: UsageWarning) -> String {
        let levelText: String
        switch warning.level {
        case .warning: levelText = "Usage warning"
        case .critical: levelText = "Usage critical"
        case .blocked: levelText = "Limit reached"
        }
        return "\(levelText). \(warning.message). \(warning.current) of \(warning.limit) used. \(warning.upgradeMessage)"
    }
    
    // MARK: - Colors
    
    private func warningColor(for level: UsageWarning.Level) -> Color {
        switch level {
        case .warning: return .orange
        case .critical: return .red
        case .blocked: return .red
        }
    }
    
    private func backgroundColor(for level: UsageWarning.Level) -> Color {
        switch level {
        case .warning: return Color.orange.opacity(0.1)
        case .critical: return Color.red.opacity(0.1)
        case .blocked: return Color.red.opacity(0.15)
        }
    }
    
    private func borderColor(for level: UsageWarning.Level) -> Color {
        switch level {
        case .warning: return Color.orange.opacity(0.3)
        case .critical: return Color.red.opacity(0.3)
        case .blocked: return Color.red.opacity(0.4)
        }
    }
}

// MARK: - Limit Reached Overlay

/// Full-screen overlay shown when a limit is reached
struct LimitReachedOverlay: View {
    let limitType: LimitType
    let currentCount: Int
    let limit: Int
    @Binding var showingSubscription: Bool
    var onDismiss: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.red)
                .accessibilityHidden(true)
            
            // Title
            Text("\(limitType.displayName.capitalized) Limit Reached")
                .accessibilityAddTraits(.isHeader)
                .font(.title2.bold())
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            
            // Message
            Text("You've used all \(limit) \(limitType.displayName) available on your current plan.")
                .font(.body)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            // Usage indicator
            HStack {
                Text("\(currentCount)")
                    .font(.title.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(.red)
                Text("of")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.secondary)
                Text("\(limit)")
                    .font(.title.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(currentCount) of \(limit) \(limitType.displayName) used")
            
            // Benefits
            VStack(alignment: .leading, spacing: 8) {
                Text("Upgrade to unlock:")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                
                benefitRow("Unlimited \(limitType.displayName)")
                
                switch limitType {
                case .transactions:
                    benefitRow("Real-time tax estimates")
                    benefitRow("Automated mileage tracking")
                case .receipts:
                    benefitRow("Smart receipt scanning with AI")
                    benefitRow("Automatic categorization")
                case .invoices:
                    benefitRow("Unlimited invoices")
                    benefitRow("Client management")
                default:
                    benefitRow("Premium features")
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Spacer()
            
            // Upgrade button
            Button {
                HapticService.play(.medium)
                showingSubscription = true
            } label: {
                Text("View Upgrade Options")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color.brandPrimary, Color.brandPrimaryDark],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            
            // Dismiss button
            if let onDismiss = onDismiss {
                Button("Maybe Later") {
                    HapticService.play(.light)
                    onDismiss()
                }
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(.secondary)
            }
            
            Spacer().frame(height: 20)
        }
        .background(Color(.systemBackground))
    }
    
    private func benefitRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

// MARK: - Inline Usage Indicator

/// Compact usage indicator for form sections (like AccountsView pattern)
struct UsageLimitIndicator: View {
    let current: Int
    let limit: Int?
    let limitType: LimitType
    @Binding var showingSubscription: Bool
    
    var body: some View {
        if let limit = limit {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(Color.brandPrimary)
                    .accessibilityHidden(true)
                
                Text("\(current) of \(limit) \(limitType.displayName) used")
                    .font(.subheadline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if current >= limit {
                    Button("Upgrade") {
                        HapticService.play(.medium)
                        showingSubscription = true
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(Color.brandPrimaryText)
                    .accessibilityHint("Double tap to view upgrade options")
                }
            }
        } else {
            HStack {
                Image(systemName: "infinity")
                    .foregroundStyle(Color.brandPrimary)
                    .accessibilityHidden(true)
                
                Text("Unlimited \(limitType.displayName)")
                    .font(.subheadline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Monthly Usage Indicator

/// Shows "X of Y this month" with reset date info
struct MonthlyUsageIndicator: View {
    let current: Int
    let limit: Int?
    let limitType: LimitType
    @Binding var showingSubscription: Bool
    
    private var daysUntilReset: Int {
        let calendar = Calendar.current
        let now = Date()
        
        // Get first day of next month
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: now),
              let firstOfNextMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: nextMonth)) else {
            return 0
        }
        
        return calendar.dateComponents([.day], from: now, to: firstOfNextMonth).day ?? 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let limit = limit {
                HStack {
                    Image(systemName: current >= limit ? "exclamationmark.triangle.fill" : "info.circle")
                        .foregroundStyle(current >= limit ? .red : Color.brandPrimary)
                        .accessibilityHidden(true)
                    
                    Text("\(current) of \(limit) \(limitType.displayName) this month")
                        .font(.subheadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(current >= limit ? .red : .secondary)
                    
                    Spacer()
                    
                    if current >= limit {
                        Button("Upgrade") {
                            HapticService.play(.medium)
                            showingSubscription = true
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(Color.brandPrimaryText)
                    }
                }
                
                if current >= Int(Double(limit) * 0.8) && current < limit {
                    Text("Resets in \(daysUntilReset) days")
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack {
                    Image(systemName: "infinity")
                        .foregroundStyle(Color.brandPrimary)
                        .accessibilityHidden(true)
                    
                    Text("Unlimited \(limitType.displayName)")
                        .font(.subheadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Warning Level") {
    VStack(spacing: 20) {
        UsageWarningBanner(
            warning: UsageWarning(
                level: .warning,
                current: 42,
                limit: 50,
                remaining: 8,
                limitType: .transactions
            ),
            showingSubscription: .constant(false)
        )
        
        UsageWarningBanner(
            warning: UsageWarning(
                level: .critical,
                current: 48,
                limit: 50,
                remaining: 2,
                limitType: .transactions
            ),
            showingSubscription: .constant(false)
        )
        
        UsageWarningBanner(
            warning: UsageWarning(
                level: .blocked,
                current: 50,
                limit: 50,
                remaining: 0,
                limitType: .transactions
            ),
            showingSubscription: .constant(false)
        )
    }
    .padding()
}

#Preview("Compact") {
    VStack(spacing: 12) {
        UsageWarningBanner(
            warning: UsageWarning(
                level: .warning,
                current: 42,
                limit: 50,
                remaining: 8,
                limitType: .transactions
            ),
            showingSubscription: .constant(false),
            isCompact: true
        )
        
        UsageWarningBanner(
            warning: UsageWarning(
                level: .blocked,
                current: 50,
                limit: 50,
                remaining: 0,
                limitType: .transactions
            ),
            showingSubscription: .constant(false),
            isCompact: true
        )
    }
    .padding()
}

#Preview("Limit Reached Overlay") {
    LimitReachedOverlay(
        limitType: .transactions,
        currentCount: 50,
        limit: 50,
        showingSubscription: .constant(false),
        onDismiss: {}
    )
}
