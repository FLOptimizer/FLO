//
//  DeductionOpportunityCard.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - Enhanced haptics and micro-animations
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES FROM v1.0:
//  ✅ Haptic feedback on card tap, view more button
//  ✅ Loading spinner animation
//  ✅ Card entrance stagger animations
//  ✅ Icon bounce effect
//  ✅ Success checkmark animation
//
//  Dashboard card displaying top tax deduction opportunities discovered
//  by TaxOptimizationEngine with real-time savings estimates.
//

import SwiftUI
import SwiftData

struct DeductionOpportunityCard: View {
    @Query private var transactions: [Transaction]
    @Query private var mileageTrips: [MileageTrip]
    @Query private var receipts: [ReceiptData]
    @Query private var taxSettings: [TaxSettings]
    @Query private var businessProfiles: [BusinessProfile]
    
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var opportunities: [TaxDeductionOpportunity] = []
    @State private var isLoading = true
    @State private var showAllOpportunities = false
    @State private var viewAppeared = false
    @State private var headerIconBounce = false
    
    // Haptic Generators
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    
    private var settings: TaxSettings {
        taxSettings.first ?? TaxSettings()
    }
    
    private var businessProfile: BusinessProfile? {
        businessProfiles.first
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader
            
            if isLoading {
                loadingView
            } else if opportunities.isEmpty {
                noOpportunitiesView
            } else {
                opportunitiesList
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        .onAppear {
            prepareHaptics()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                viewAppeared = true
            }
            Task {
                await analyzeOpportunities()
            }
        }
        .sheet(isPresented: $showAllOpportunities) {
            DeductionOpportunitiesView(opportunities: opportunities)
        }
    }
    
    // MARK: - Haptic Preparation
    
    private func prepareHaptics() {
        impactLight.prepare()
        impactMedium.prepare()
    }
    
    // MARK: - Header
    
    private var cardHeader: some View {
        HStack {
            Image(systemName: "lightbulb.fill")
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "FBBF24"), Color(hex: "F59E0B")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolEffect(.bounce, value: headerIconBounce)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Tax Opportunities")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                if !opportunities.isEmpty {
                    Text("$\(String(format: "%.0f", totalSavings)) potential savings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            }
            
            Spacer()
            
            if !opportunities.isEmpty {
                Button {
                    impactLight.impactOccurred()
                    showAllOpportunities = true
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundColor(Color.brandPrimary)
                }
            }
        }
        .padding()
        .opacity(viewAppeared ? 1 : 0)
        .offset(y: viewAppeared ? 0 : 10)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: viewAppeared)
    }
    
    // MARK: - Loading State
    
    private var loadingView: some View {
        HStack {
            ProgressView()
                .tint(Color.brandPrimary)
            Text("Analyzing your deductions...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .opacity(viewAppeared ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: viewAppeared)
    }
    
    // MARK: - No Opportunities
    
    private var noOpportunitiesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.green)
                .symbolEffect(.bounce, value: viewAppeared)
            
            Text("Looking good!")
                .font(.headline)
            
            Text("We didn't find any missed deductions. Keep tracking your expenses!")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .opacity(viewAppeared ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: viewAppeared)
    }
    
    // MARK: - Opportunities List
    
    private var opportunitiesList: some View {
        VStack(spacing: 12) {
            ForEach(Array(topOpportunities.enumerated()), id: \.element.id) { index, opportunity in
                OpportunityRow(opportunity: opportunity)
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(x: viewAppeared ? 0 : 20)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.8)
                        .delay(0.1 + Double(index) * 0.05),
                        value: viewAppeared
                    )
            }
            
            if opportunities.count > 3 {
                Button {
                    impactMedium.impactOccurred()
                    showAllOpportunities = true
                } label: {
                    HStack {
                        Text("View \(opportunities.count - 3) more opportunities")
                            .font(.subheadline.bold())
                        Image(systemName: "arrow.right")
                            .font(.caption)
                    }
                    .foregroundColor(Color.brandPrimary)
                }
                .padding(.top, 4)
                .opacity(viewAppeared ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.25), value: viewAppeared)
            }
        }
        .padding()
    }
    
    // MARK: - Helper Views
    
    struct OpportunityRow: View {
        let opportunity: TaxDeductionOpportunity
        @State private var showDetail = false
        @State private var isPressed = false
        
        private let impactLight = UIImpactFeedbackGenerator(style: .light)
        
        var body: some View {
            Button {
                impactLight.impactOccurred()
                showDetail = true
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Text(opportunity.category.emoji)
                        .font(.title2)
                        .frame(width: 40, height: 40)
                        .background(Color.brandPrimary.opacity(0.1))
                        .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(opportunity.title)
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        
                        Text(opportunity.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        
                        HStack(spacing: 12) {
                            Label {
                                Text("$\(String(format: "%.0f", opportunity.estimatedSavings))")
                                    .font(.caption.bold())
                            } icon: {
                                Image(systemName: "dollarsign.circle.fill")
                                    .foregroundColor(.green)
                            }
                            
                            if opportunity.riskLevel != .low {
                                Label {
                                    Text(opportunity.riskLevel.rawValue)
                                        .font(.caption)
                                } icon: {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(
                                            opportunity.riskLevel == .high ? .red : .orange
                                        )
                                }
                            }
                            
                            if opportunity.requiresProTier {
                                Label {
                                    Text("Pro")
                                        .font(.caption2.bold())
                                } icon: {
                                    Image(systemName: "crown.fill")
                                }
                                .foregroundColor(.purple)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(4)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(10)
                .scaleEffect(isPressed ? 0.98 : 1.0)
            }
            .buttonStyle(.plain)
            .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isPressed = pressing
                }
            }, perform: {})
            .sheet(isPresented: $showDetail) {
                DeductionDetailView(opportunity: opportunity)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var topOpportunities: [TaxDeductionOpportunity] {
        Array(opportunities.prefix(3))
    }
    
    private var totalSavings: Double {
        opportunities.reduce(0) { $0 + $1.estimatedSavings }
    }
    
    // MARK: - Analysis
    
    @MainActor
    private func analyzeOpportunities() async {
        // Small delay for UI smoothness
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        guard let context = transactions.first?.modelContext else {
            isLoading = false
            return
        }
        
        // Run analysis
        opportunities = TaxOptimizationEngine.shared.scanForMissedDeductions(
            transactions: transactions,
            mileageTrips: mileageTrips,
            receipts: receipts,
            taxSettings: settings,
            businessProfile: businessProfile,
            context: context
        )
        
        isLoading = false
        
        // Trigger header bounce after loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            headerIconBounce.toggle()
        }
        
        #if DEBUG
        print("💡 Tax Opportunities: \(opportunities.count) found")
        print("   Total potential savings: $\(String(format: "%.0f", totalSavings))")
        #endif
    }
}

// MARK: - Deduction Detail View

struct DeductionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    let opportunity: TaxDeductionOpportunity
    @State private var showingPaywall = false
    @State private var viewAppeared = false
    
    // Haptic Generators
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Category header
                    HStack {
                        Text(opportunity.category.emoji)
                            .font(.system(size: 48))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(opportunity.title)
                                .font(.title2.bold())
                            Text(opportunity.category.displayName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top)
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(y: viewAppeared ? 0 : 15)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: viewAppeared)
                    
                    // Savings estimate
                    savingsCard
                        .opacity(viewAppeared ? 1 : 0)
                        .offset(y: viewAppeared ? 0 : 15)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: viewAppeared)
                    
                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What This Means")
                            .font(.headline)
                        
                        Text(opportunity.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(y: viewAppeared ? 0 : 15)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: viewAppeared)
                    
                    // Action items
                    if !opportunity.actionItems.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Next Steps")
                                .font(.headline)
                            
                            ForEach(Array(opportunity.actionItems.enumerated()), id: \.offset) { index, item in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                        .frame(width: 24, height: 24)
                                        .background(Color.brandPrimary)
                                        .cornerRadius(12)
                                    
                                    Text(item)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .opacity(viewAppeared ? 1 : 0)
                        .offset(y: viewAppeared ? 0 : 15)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: viewAppeared)
                    }
                    
                    // Risk assessment
                    riskCard
                        .opacity(viewAppeared ? 1 : 0)
                        .offset(y: viewAppeared ? 0 : 15)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.25), value: viewAppeared)
                    
                    // IRS citation
                    if let citation = opportunity.irsCitation {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Learn More")
                                .font(.headline)
                            
                            Text(citation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .opacity(viewAppeared ? 1 : 0)
                        .offset(y: viewAppeared ? 0 : 15)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3), value: viewAppeared)
                    }
                    
                    // Disclaimer
                    disclaimerView
                        .opacity(viewAppeared ? 1 : 0)
                        .offset(y: viewAppeared ? 0 : 15)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.35), value: viewAppeared)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        impactLight.impactOccurred()
                        dismiss()
                    }
                }
            }
            .onAppear {
                impactLight.prepare()
                impactMedium.prepare()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    viewAppeared = true
                }
            }
        }
        .sheet(isPresented: $showingPaywall) {
            SubscriptionView()
        }
    }
    
    private var savingsCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Estimated Tax Savings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("$\(String(format: "%.0f", opportunity.estimatedSavings))")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.green)
                        .contentTransition(.numericText())
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Confidence")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("\(Int(opportunity.confidence * 100))%")
                        .font(.title3.bold())
                        .foregroundColor(Color.brandPrimary)
                }
            }
            
            if opportunity.requiresProTier && subscriptionManager.currentTier != .pro {
                Button {
                    impactMedium.impactOccurred()
                    showingPaywall = true
                } label: {
                    HStack {
                        Image(systemName: "crown.fill")
                        Text("Upgrade to Pro to unlock")
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.purple.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(10)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.green.opacity(0.1), Color.brandPrimary.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
    }
    
    private var riskCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Audit Risk")
                    .font(.headline)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text(opportunity.riskLevel.emoji)
                    Text(opportunity.riskLevel.rawValue)
                        .font(.subheadline.bold())
                        .foregroundColor(
                            opportunity.riskLevel == .low ? .green :
                            opportunity.riskLevel == .medium ? .orange : .red
                        )
                }
            }
            
            Text(riskDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private var riskDescription: String {
        switch opportunity.riskLevel {
        case .low:
            return "This deduction has low audit risk when properly documented. Follow the action steps above and keep good records."
        case .medium:
            return "This deduction requires careful documentation. The IRS may scrutinize this category, so follow all recommendations and keep detailed records."
        case .high:
            return "⚠️ This is an advanced strategy with higher audit risk. Consult with a CPA before implementing. Proper documentation is critical."
        }
    }
    
    private var disclaimerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.orange)
                Text("Important Disclaimer")
                    .font(.caption.bold())
            }
            
            Text("This is tax guidance, not tax advice. FLO provides estimates based on IRS rules, but your specific situation may vary. Consult a licensed CPA or tax professional for personalized advice.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Preview Provider

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Transaction.self, MileageTrip.self, ReceiptData.self,
        TaxSettings.self, BusinessProfile.self,
        configurations: config
    )
    
    return DeductionOpportunityCard()
        .modelContainer(container)
        .padding()
}
