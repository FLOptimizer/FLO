//
//  DeductionOpportunityCard.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.4 - Dynamic Type verification
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.2:
//  ✅ Card header accessible with total savings announced
//  ✅ Loading and empty states have VoiceOver labels
//  ✅ Each opportunity row fully accessible with savings estimate
//  ✅ View more button properly labeled
//  ✅ Detail view sections accessible with headers
//  ✅ Risk level and confidence announced
//  ✅ Pro upgrade button accessible
//
//  CHANGES FROM v1.1:
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
    @State private var transactions: [Transaction] = []
    @State private var mileageTrips: [MileageTrip] = []
    @State private var receipts: [ReceiptData] = []
    @Query private var taxSettings: [TaxSettings]
    @Query private var businessProfiles: [BusinessProfile]
    
    @Environment(\.modelContext) private var modelContext
    
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var opportunities: [TaxDeductionOpportunity] = []
    @State private var isLoading = true
    @State private var showAllOpportunities = false
    @State private var viewAppeared = false
    @State private var headerIconBounce = false
    
    private var settings: TaxSettings {
        taxSettings.first ?? TaxSettings()
    }
    
    private var businessProfile: BusinessProfile? {
        businessProfiles.first
    }
    
    private var topOpportunities: [TaxDeductionOpportunity] {
        Array(opportunities.prefix(3))
    }
    
    private var totalSavings: Double {
        opportunities.reduce(0) { $0 + $1.estimatedSavings }
    }
    
    // MARK: - Accessibility Labels
    
    private var cardAccessibilityLabel: String {
        if isLoading {
            return "Tax opportunities. Analyzing your deductions."
        } else if opportunities.isEmpty {
            return "Tax opportunities. Looking good! No missed deductions found."
        } else {
            return "Tax opportunities. \(opportunities.count) found with \(totalSavings.accessibilityCurrency) potential savings."
        }
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
        .background(Color.floSecondarySystemGroupedBackground)
        .cornerRadius(12)
        .floCardShadow(radius: 5)
        .accessibilityElement(children: .contain)
        .task { loadData() }
        .onAppear {
            withAnimation(FLOAnimation.standard) {
                viewAppeared = true
            }
            Task {
                await analyzeOpportunities()
            }
        }
        .onDisappear {
            transactions = []
            mileageTrips = []
            receipts = []
        }
        .sheet(isPresented: $showAllOpportunities) {
            DeductionOpportunitiesView(opportunities: opportunities)
        }
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
                .accessibilityHidden(true)
                .symbolEffect(.bounce, value: headerIconBounce)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Tax Opportunities")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                
                if !opportunities.isEmpty {
                    Text("$\(String(format: "%.0f", totalSavings)) potential savings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .contentTransition(.numericText())
                }
            }
            
            Spacer()
            
            if !opportunities.isEmpty {
                Button {
                    HapticService.play(.light)
                    showAllOpportunities = true
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundColor(Color.brandPrimary)
                        .accessibilityHidden(true)
                }
                .accessibilityLabel("View all tax opportunities")
                .accessibilityHint("Shows detailed list of all \(opportunities.count) deduction opportunities")
            }
        }
        .padding()
        .opacity(viewAppeared ? 1 : 0.001)
        .offset(y: viewAppeared ? 0 : 10)
        .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel(cardAccessibilityLabel)
    }
    
    // MARK: - Loading State
    
    private var loadingView: some View {
        HStack {
            ProgressView()
                .tint(Color.brandPrimary)
                .accessibilityHidden(true)
            Text("Analyzing your deductions...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .opacity(viewAppeared ? 1 : 0.001)
        .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Analyzing your tax deductions, please wait")
    }
    
    // MARK: - No Opportunities
    
    private var noOpportunitiesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundColor(.green)
                .symbolEffect(.bounce, value: viewAppeared)
                .accessibilityHidden(true)
            
            Text("Looking good!")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            
            Text("We didn't find any missed deductions. Keep tracking your expenses!")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .opacity(viewAppeared ? 1 : 0.001)
        .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Looking good! No missed deductions found. Keep tracking your expenses.")
    }
    
    // MARK: - Opportunities List
    
    private var opportunitiesList: some View {
        VStack(spacing: 12) {
            ForEach(Array(topOpportunities.enumerated()), id: \.element.id) { index, opportunity in
                OpportunityRow(opportunity: opportunity)
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(x: viewAppeared ? 0 : 20)
                    .animation(
                        FLOAnimation.standard
                        .delay(0.1 + Double(index) * 0.05),
                        value: viewAppeared
                    )
            }
            
            if opportunities.count > 3 {
                Button {
                    HapticService.play(.medium)
                    showAllOpportunities = true
                } label: {
                    HStack {
                        Text("View \(opportunities.count - 3) more opportunities")
                            .font(.subheadline.bold())
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .accessibilityHidden(true)
                    }
                    .foregroundColor(Color.brandPrimary)
                }
                .padding(.top, 4)
                .opacity(viewAppeared ? 1 : 0.001)
                .animation(FLOAnimation.standard.delay(0.25), value: viewAppeared)
                .accessibilityLabel("View \(opportunities.count - 3) more tax opportunities")
                .accessibilityHint("Opens full list of deduction opportunities")
            }
        }
        .padding()
    }
    
    // MARK: - Data Loading

    private func loadData() {
        let calendar = Calendar.current
        let yearStart = calendar.date(from: calendar.dateComponents([.year], from: Date()))!

        transactions = (try? modelContext.fetch(FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.date >= yearStart }
        ))) ?? []

        mileageTrips = (try? modelContext.fetch(FetchDescriptor<MileageTrip>(
            predicate: #Predicate<MileageTrip> { $0.startDate >= yearStart }
        ))) ?? []

        receipts = (try? modelContext.fetch(FetchDescriptor<ReceiptData>(
            predicate: #Predicate<ReceiptData> { $0.date >= yearStart }
        ))) ?? []
    }

    // MARK: - Analysis

    @MainActor
    private func analyzeOpportunities() async {
        // Use the shared singleton instance
        let foundOpportunities = TaxOptimizationEngine.shared.scanForMissedDeductions(
            transactions: transactions,
            mileageTrips: mileageTrips,
            receipts: receipts,
            taxSettings: settings,
            businessProfile: businessProfile,
            context: modelContext
        )
        
        withAnimation(FLOAnimation.standard) {
            self.opportunities = foundOpportunities
            self.isLoading = false
            self.headerIconBounce.toggle()
        }
    }
}

// MARK: - Opportunity Row

struct OpportunityRow: View {
    let opportunity: TaxDeductionOpportunity
    @State private var showDetail = false
    @State private var isPressed = false
    
    private var accessibilityDescription: String {
        var desc = "\(opportunity.title). "
        desc += "Estimated savings: \(opportunity.estimatedSavings.accessibilityCurrency). "
        desc += "Confidence: \(Int(opportunity.confidence * 100)) percent. "
        desc += "Risk level: \(opportunity.riskLevel.rawValue)."
        if opportunity.requiresProTier {
            desc += " Requires Pro subscription."
        }
        return desc
    }
    
    var body: some View {
        Button {
            HapticService.play(.light)
            showDetail = true
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Text(opportunity.category.emoji)
                    .font(.title2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: 40, height: 40)
                    .background(Color.floTertiarySystemBackground)
                    .cornerRadius(8)
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(opportunity.title)
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        if opportunity.requiresProTier {
                            Image(systemName: "crown.fill")
                                .font(.caption2)
                                .foregroundColor(.purple)
                                .accessibilityHidden(true)
                        }
                    }
                    
                    Text(opportunity.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(String(format: "%.0f", opportunity.estimatedSavings))")
                        .font(.subheadline.bold())
                        .foregroundColor(.green)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    Text("\(Int(opportunity.confidence * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(12)
            .background(Color.floTertiarySystemBackground)
            .cornerRadius(10)
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .sheet(isPresented: $showDetail) {
            OpportunityDetailView(opportunity: opportunity)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Double tap to view details and action steps")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Opportunity Detail View

/// Alias for backward compatibility with DeductionOpportunitiesView
typealias DeductionDetailView = OpportunityDetailView

struct OpportunityDetailView: View {
    let opportunity: TaxDeductionOpportunity
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showingPaywall = false
    @State private var viewAppeared = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack {
                        Text(opportunity.category.emoji)
                            .font(.largeTitle)
                            .accessibilityHidden(true)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(opportunity.title)
                                .font(.title2.bold())
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            
                            HStack(spacing: 8) {
                                Label(opportunity.riskLevel.rawValue, systemImage: "shield.fill")
                                    .font(.caption)
                                    .foregroundColor(
                                        opportunity.riskLevel == .low ? .green :
                                        opportunity.riskLevel == .medium ? .orange : .red
                                    )
                                
                                if opportunity.requiresProTier {
                                    Label("Pro", systemImage: "crown.fill")
                                        .font(.caption)
                                        .foregroundColor(.purple)
                                }
                            }
                        }
                    }
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(opportunity.title). Risk level: \(opportunity.riskLevel.rawValue). \(opportunity.requiresProTier ? "Requires Pro subscription." : "")")
                    
                    // Description
                    Text(opportunity.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .opacity(viewAppeared ? 1 : 0.001)
                        .offset(y: viewAppeared ? 0 : 10)
                        .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
                    
                    // Savings card
                    savingsCard
                        .opacity(viewAppeared ? 1 : 0.001)
                        .offset(y: viewAppeared ? 0 : 15)
                        .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)
                    
                    // Action items
                    if !opportunity.actionItems.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Next Steps")
                                .font(.headline)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .accessibilityAddTraits(.isHeader)
                            
                            ForEach(Array(opportunity.actionItems.enumerated()), id: \.offset) { index, item in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                        .frame(width: 24, height: 24)
                                        .background(Color.brandPrimary)
                                        .cornerRadius(12)
                                        .accessibilityHidden(true)
                                    
                                    Text(item)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("Step \(index + 1): \(item)")
                            }
                        }
                        .padding()
                        .background(Color.floSecondarySystemGroupedBackground)
                        .cornerRadius(12)
                        .opacity(viewAppeared ? 1 : 0.001)
                        .offset(y: viewAppeared ? 0 : 15)
                        .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)
                    }
                    
                    // Risk assessment
                    riskCard
                        .opacity(viewAppeared ? 1 : 0.001)
                        .offset(y: viewAppeared ? 0 : 15)
                        .animation(FLOAnimation.standard.delay(0.25), value: viewAppeared)
                    
                    // IRS citation
                    if let citation = opportunity.irsCitation {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Learn More")
                                .font(.headline)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .accessibilityAddTraits(.isHeader)
                            
                            Text(citation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color.floSecondarySystemGroupedBackground)
                        .cornerRadius(12)
                        .opacity(viewAppeared ? 1 : 0.001)
                        .offset(y: viewAppeared ? 0 : 15)
                        .animation(FLOAnimation.standard.delay(0.3), value: viewAppeared)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("IRS Reference: \(citation)")
                    }
                    
                    // Disclaimer
                    disclaimerView
                        .opacity(viewAppeared ? 1 : 0.001)
                        .offset(y: viewAppeared ? 0 : 15)
                        .animation(FLOAnimation.standard.delay(0.35), value: viewAppeared)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        HapticService.play(.light)
                        dismiss()
                    }
                    .accessibilityLabel("Close details")
                }
            }
            .onAppear {
                withAnimation(FLOAnimation.standard) {
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
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.numericText())
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Confidence")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("\(Int(opportunity.confidence * 100))%")
                        .font(.title3.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundColor(Color.brandPrimary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Estimated tax savings: \(opportunity.estimatedSavings.accessibilityCurrency). Confidence level: \(Int(opportunity.confidence * 100)) percent.")
            
            if opportunity.requiresProTier && subscriptionManager.currentTier != .pro {
                Button {
                    HapticService.play(.medium)
                    showingPaywall = true
                } label: {
                    HStack {
                        Image(systemName: "crown.fill")
                            .accessibilityHidden(true)
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
                .accessibilityLabel("Upgrade to Pro to unlock this deduction opportunity")
                .accessibilityHint("Opens subscription options")
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text(opportunity.riskLevel.emoji)
                        .accessibilityHidden(true)
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
        .background(Color.floSecondarySystemGroupedBackground)
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Audit risk: \(opportunity.riskLevel.rawValue). \(riskDescription)")
    }
    
    private var riskDescription: String {
        switch opportunity.riskLevel {
        case .low:
            return "This deduction has low audit risk when properly documented. Follow the action steps above and keep good records."
        case .medium:
            return "This deduction requires careful documentation. The IRS may scrutinize this category, so follow all recommendations and keep detailed records."
        case .high:
            return "This is an advanced strategy with higher audit risk. Consult with a CPA before implementing. Proper documentation is critical."
        }
    }
    
    private var disclaimerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.orange)
                    .accessibilityHidden(true)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Important disclaimer: This is tax guidance, not tax advice. Consult a licensed CPA or tax professional for personalized advice.")
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
