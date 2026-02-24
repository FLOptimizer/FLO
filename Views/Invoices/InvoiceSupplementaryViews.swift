//  InvoiceSupplementaryViews.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.3 - VoiceOver Audit: Verified accessibility
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Mark as paid and aging report views
//
//  CHANGES v2.3 - VoiceOver Audit:
//  ✅ VERIFIED: Lightbulb icons in AnimatedInsightRow already hidden from VoiceOver
//  ✅ VERIFIED: Chart bar labels already hidden, proper accessibility labels on bars
//  ✅ VERIFIED: AnimatedAgingBucketRow has combined accessibility labels
//  ✅ NOTE: Aging bucket rows are tappable for haptic feedback but don't navigate/filter,
//           so no accessibilityHint is needed (purely visual feedback on tap)
//
//  ENHANCEMENTS v2.0:
//  - Animated header with counter effect
//  - Staggered bucket row entrance animations
//  - Chart bars with spring animation on appear
//  - Insight lightbulb pulse effect
//  - Haptic feedback on navigation
//

import SwiftUI
import SwiftData

// MARK: - Aging Report View

struct AgingReportView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allInvoices: [Invoice]
    
    // Animation States
    @State private var headerVisible = false
    @State private var bucketsVisible = false
    @State private var chartVisible = false
    @State private var insightsVisible = false
    @State private var amountAnimated: Double = 0
    
    var unpaidInvoices: [Invoice] {
        allInvoices.filter { $0.status != .paid && $0.status != .cancelled }
    }
    
    var agingBuckets: AgingReport {
        var report = AgingReport()
        
        for invoice in unpaidInvoices {
            let daysOutstanding = invoice.daysOverdue
            
            if daysOutstanding < 0 {
                report.current.count += 1
                report.current.amount += invoice.totalAmount
            } else if daysOutstanding <= 30 {
                report.days0to30.count += 1
                report.days0to30.amount += invoice.totalAmount
            } else if daysOutstanding <= 60 {
                report.days31to60.count += 1
                report.days31to60.amount += invoice.totalAmount
            } else if daysOutstanding <= 90 {
                report.days61to90.count += 1
                report.days61to90.amount += invoice.totalAmount
            } else {
                report.days90plus.count += 1
                report.days90plus.amount += invoice.totalAmount
            }
        }
        
        return report
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header summary
                    VStack(spacing: 8) {
                        Text("Total Outstanding")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .accessibilityAddTraits(.isHeader)
                        
                        Text(amountAnimated.formatted(.currency(code: "USD")))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.brandPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .contentTransition(.numericText())
                        
                        Text("\(agingBuckets.totalCount) invoices")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.05), radius: 8)
                    .scaleEffect(headerVisible ? 1.0 : 0.95)
                    .opacity(headerVisible ? 1 : 0.001)
                    
                    // Aging buckets
                    VStack(spacing: 12) {
                        AnimatedAgingBucketRow(
                            title: "Current",
                            subtitle: "Not yet due",
                            count: agingBuckets.current.count,
                            amount: agingBuckets.current.amount,
                            color: .green,
                            delay: 0,
                            isVisible: bucketsVisible
                        )
                        
                        AnimatedAgingBucketRow(
                            title: "0-30 Days",
                            subtitle: "Recently overdue",
                            count: agingBuckets.days0to30.count,
                            amount: agingBuckets.days0to30.amount,
                            color: .yellow,
                            delay: 0.05,
                            isVisible: bucketsVisible
                        )
                        
                        AnimatedAgingBucketRow(
                            title: "31-60 Days",
                            subtitle: "Needs attention",
                            count: agingBuckets.days31to60.count,
                            amount: agingBuckets.days31to60.amount,
                            color: .orange,
                            delay: 0.1,
                            isVisible: bucketsVisible
                        )
                        
                        AnimatedAgingBucketRow(
                            title: "61-90 Days",
                            subtitle: "Serious concern",
                            count: agingBuckets.days61to90.count,
                            amount: agingBuckets.days61to90.amount,
                            color: .red,
                            delay: 0.15,
                            isVisible: bucketsVisible
                        )
                        
                        AnimatedAgingBucketRow(
                            title: "90+ Days",
                            subtitle: "Collection needed",
                            count: agingBuckets.days90plus.count,
                            amount: agingBuckets.days90plus.amount,
                            color: .red,
                            delay: 0.2,
                            isVisible: bucketsVisible
                        )
                    }
                    
                    // Chart
                    if agingBuckets.totalCount > 0 {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Distribution")
                                .font(.headline)
                                .accessibilityAddTraits(.isHeader)
                            
                            AnimatedAgingChartView(report: agingBuckets, isVisible: chartVisible)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.05), radius: 8)
                        .opacity(chartVisible ? 1 : 0.001)
                        .offset(y: chartVisible ? 0 : 20)
                    }
                    
                    // Insights
                    if !insights.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Insights")
                                .font(.headline)
                                .accessibilityAddTraits(.isHeader)
                            
                            ForEach(Array(insights.enumerated()), id: \.offset) { index, insight in
                                AnimatedInsightRow(
                                    insight: insight,
                                    delay: Double(index) * 0.1,
                                    isVisible: insightsVisible
                                )
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.05), radius: 8)
                        .opacity(insightsVisible ? 1 : 0.001)
                        .offset(y: insightsVisible ? 0 : 20)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Aging Report")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                animateEntrance()
                AccessibilityAnnouncement.screenChanged("Aging report")
            }
        }
    }
    
    // MARK: - Animations
    
    private func animateEntrance() {
        HapticService.play(.medium)
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            headerVisible = true
        }
        
        // Animate amount counter
        animateAmount()
        
        withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
            bucketsVisible = true
        }
        
        withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
            chartVisible = true
        }
        
        withAnimation(.easeOut(duration: 0.4).delay(0.7)) {
            insightsVisible = true
        }
    }
    
    private func animateAmount() {
        let targetAmount = agingBuckets.totalAmount
        let duration = 0.8
        let steps = 30
        let stepDuration = duration / Double(steps)
        
        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + (stepDuration * Double(i))) {
                withAnimation(.easeOut(duration: 0.02)) {
                    amountAnimated = targetAmount * Double(i) / Double(steps)
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.05) {
            amountAnimated = targetAmount
        }
    }
    
    private var insights: [String] {
        var messages: [String] = []
        
        let totalOverdue = agingBuckets.days0to30.amount + agingBuckets.days31to60.amount +
                          agingBuckets.days61to90.amount + agingBuckets.days90plus.amount
        
        if totalOverdue > 0 {
            let percentage = (totalOverdue / agingBuckets.totalAmount) * 100
            messages.append(String(format: "%.0f%% of outstanding invoices are overdue", percentage))
        }
        
        if agingBuckets.days90plus.count > 0 {
            messages.append("\(agingBuckets.days90plus.count) invoice(s) over 90 days may need collection action")
        }
        
        if agingBuckets.current.amount > totalOverdue && totalOverdue > 0 {
            messages.append("Most receivables are current - good cash flow management")
        }
        
        return messages
    }
}

// MARK: - Animated Aging Bucket Row

struct AnimatedAgingBucketRow: View {
    let title: String
    let subtitle: String
    let count: Int
    let amount: Double
    let color: Color
    let delay: Double
    let isVisible: Bool
    
    @State private var isPressed = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(amount.formatted(.currency(code: "USD")))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)
                Text("\(count) invoice\(count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.3), lineWidth: 2)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .opacity(isVisible ? 1 : 0.001)
        .offset(x: isVisible ? 0 : -20)
        .animation(FLOAnimation.quick.delay(delay), value: isVisible)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(subtitle). \(count) invoice\(count == 1 ? "" : "s"), \(amount.formatted(.currency(code: "USD")))")
        .onTapGesture {
            HapticService.play(.medium)
            
            withAnimation(.spring(response: 0.15, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.15, dampingFraction: 0.6)) {
                    isPressed = false
                }
            }
        }
    }
}

// MARK: - Animated Aging Chart View

struct AnimatedAgingChartView: View {
    let report: AgingReport
    let isVisible: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            AnimatedChartBar(amount: report.current.amount, total: report.totalAmount, color: .green, label: "Current", delay: 0, isVisible: isVisible)
            AnimatedChartBar(amount: report.days0to30.amount, total: report.totalAmount, color: .yellow, label: "0-30", delay: 0.05, isVisible: isVisible)
            AnimatedChartBar(amount: report.days31to60.amount, total: report.totalAmount, color: .orange, label: "31-60", delay: 0.1, isVisible: isVisible)
            AnimatedChartBar(amount: report.days61to90.amount, total: report.totalAmount, color: .red, label: "61-90", delay: 0.15, isVisible: isVisible)
            AnimatedChartBar(amount: report.days90plus.amount, total: report.totalAmount, color: .red, label: "90+", delay: 0.2, isVisible: isVisible)
        }
    }
}

struct AnimatedChartBar: View {
    let amount: Double
    let total: Double
    let color: Color
    let label: String
    let delay: Double
    let isVisible: Bool
    
    @State private var barWidth: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .frame(width: 50, alignment: .leading)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: barWidth)
                }
                .onAppear {
                    if isVisible {
                        animateBar(maxWidth: geometry.size.width)
                    }
                }
                .onChange(of: isVisible) { _, newValue in
                    if newValue {
                        animateBar(maxWidth: geometry.size.width)
                    }
                }
            }
            .frame(height: 24)
            
            Text(amount.formatted(.currency(code: "USD")))
                .font(.caption)
                .frame(width: 80, alignment: .trailing)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(amount.formatted(.currency(code: "USD")))")
    }
    
    private func animateBar(maxWidth: CGFloat) {
        let targetWidth = total > 0 ? maxWidth * (amount / total) : 0
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(delay)) {
            barWidth = targetWidth
        }
    }
}

// MARK: - Animated Insight Row

struct AnimatedInsightRow: View {
    let insight: String
    let delay: Double
    let isVisible: Bool
    
    @State private var lightbulbPulse = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.yellow)
                .font(.caption)
                .scaleEffect(lightbulbPulse ? 1.1 : 1.0)
                .accessibilityHidden(true)
            
            Text(insight)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .opacity(isVisible ? 1 : 0.001)
        .offset(x: isVisible ? 0 : -10)
        .animation(.easeOut(duration: 0.3).delay(delay), value: isVisible)
        .onAppear {
            if isVisible {
                startPulse()
            }
        }
        .onChange(of: isVisible) { _, newValue in
            if newValue {
                startPulse()
            }
        }
    }
    
    private func startPulse() {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.3) {
            withAnimation(FLOAnimation.slowEase.repeatCount(2, autoreverses: true)) {
                lightbulbPulse = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                lightbulbPulse = false
            }
        }
    }
}

// MARK: - Data Models

struct AgingReport {
    struct Bucket {
        var count: Int = 0
        var amount: Double = 0
    }
    
    var current = Bucket()
    var days0to30 = Bucket()
    var days31to60 = Bucket()
    var days61to90 = Bucket()
    var days90plus = Bucket()
    
    var totalCount: Int {
        current.count + days0to30.count + days31to60.count + days61to90.count + days90plus.count
    }
    
    var totalAmount: Double {
        current.amount + days0to30.amount + days31to60.amount + days61to90.amount + days90plus.amount
    }
}

#Preview {
    AgingReportView()
        .modelContainer(for: [Invoice.self])
}
