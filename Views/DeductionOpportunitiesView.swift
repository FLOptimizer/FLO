//
//  DeductionOpportunitiesView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - Enhanced haptics and micro-animations
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES FROM v1.0:
//  ✅ Haptic feedback on filter chips, sort menu
//  ✅ Card tap haptics
//  ✅ Entrance animations for summary and cards
//  ✅ Filter chip selection animation
//  ✅ Empty state icon animation
//
//  Comprehensive view of all tax deduction opportunities discovered
//  by the AI optimization engine, with filtering and sorting options.
//

import SwiftUI

struct DeductionOpportunitiesView: View {
    @Environment(\.dismiss) private var dismiss
    let opportunities: [TaxDeductionOpportunity]
    
    @State private var searchText = ""
    @State private var selectedFilter: OpportunityFilter = .all
    @State private var sortOrder: SortOrder = .savingsDescending
    @State private var viewAppeared = false
    
    // Haptic Generators
                
    enum OpportunityFilter: String, CaseIterable {
        case all = "All"
        case highSavings = "High Savings"
        case lowRisk = "Low Risk"
        case actionable = "Quick Wins"
        
        var icon: String {
            switch self {
            case .all: return "list.bullet"
            case .highSavings: return "dollarsign.circle.fill"
            case .lowRisk: return "checkmark.shield.fill"
            case .actionable: return "bolt.fill"
            }
        }
    }
    
    enum SortOrder: String, CaseIterable {
        case savingsDescending = "Highest Savings"
        case savingsAscending = "Lowest Savings"
        case riskAscending = "Lowest Risk"
        case riskDescending = "Highest Risk"
        
        var icon: String {
            switch self {
            case .savingsDescending: return "arrow.down.circle.fill"
            case .savingsAscending: return "arrow.up.circle.fill"
            case .riskAscending: return "shield.fill"
            case .riskDescending: return "exclamationmark.triangle.fill"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                summaryHeader
                filterChips
                
                if filteredOpportunities.isEmpty {
                    emptyStateView
                } else {
                    opportunitiesList
                }
            }
            .navigationTitle("Tax Opportunities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        HapticService.play(.light)
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Sort By", selection: $sortOrder) {
                            ForEach(SortOrder.allCases, id: \.self) { order in
                                Label(order.rawValue, systemImage: order.icon)
                                    .tag(order)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                            .foregroundColor(.brandPrimary)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search opportunities")
            .onChange(of: sortOrder) { _, _ in
                HapticService.play(.selection)
            }
            .onAppear {
                                withAnimation(FLOAnimation.standard) {
                    viewAppeared = true
                }
            }
        }
    }
    
    // MARK: - Haptic Preparation
    
        
    // MARK: - Summary Header
    
    private var summaryHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("\(filteredOpportunities.count)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.brandPrimary)
                        .contentTransition(.numericText())
                    
                    Text("Opportunities")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                    .frame(height: 40)
                
                VStack(spacing: 4) {
                    Text("$\(String(format: "%.0f", totalSavings))")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.green)
                        .contentTransition(.numericText())
                    
                    Text("Potential Savings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.top)
        }
        .opacity(viewAppeared ? 1 : 0)
        .offset(y: viewAppeared ? 0 : 15)
        .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)
    }
    
    // MARK: - Filter Chips
    
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(OpportunityFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        filter: filter,
                        isSelected: selectedFilter == filter
                    ) {
                        HapticService.play(.selection)
                        withAnimation(FLOAnimation.quick) {
                            selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .opacity(viewAppeared ? 1 : 0)
        .offset(y: viewAppeared ? 0 : 10)
        .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
    }
    
    struct FilterChip: View {
        let filter: OpportunityFilter
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: 6) {
                    Image(systemName: filter.icon)
                        .font(.caption)
                    Text(filter.rawValue)
                        .font(.subheadline.bold())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isSelected ? Color.brandPrimary : Color(.secondarySystemGroupedBackground)
                )
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
                .scaleEffect(isSelected ? 1.02 : 1.0)
            }
            .animation(FLOAnimation.quick, value: isSelected)
        }
    }
    
    // MARK: - Opportunities List
    
    private var opportunitiesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(sortedOpportunities.enumerated()), id: \.element.id) { index, opportunity in
                    OpportunityCard(opportunity: opportunity)
                        .opacity(viewAppeared ? 1 : 0)
                        .offset(y: viewAppeared ? 0 : 20)
                        .animation(
                            FLOAnimation.standard
                            .delay(0.15 + Double(index) * 0.05),
                            value: viewAppeared
                        )
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
    
    struct OpportunityCard: View {
        let opportunity: TaxDeductionOpportunity
        @State private var showDetail = false
        @State private var isPressed = false
        
                
        var body: some View {
            Button {
                HapticService.play(.light)
                showDetail = true
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    // Header
                    HStack(spacing: 12) {
                        Text(opportunity.category.emoji)
                            .font(.system(size: 32))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(opportunity.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            
                            Text(opportunity.category.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    // Description
                    Text(opportunity.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    
                    Divider()
                    
                    // Metrics
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(systemName: "dollarsign.circle.fill")
                                .foregroundColor(.green)
                            Text("$\(String(format: "%.0f", opportunity.estimatedSavings))")
                                .font(.subheadline.bold())
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(.blue)
                            Text("\(Int(opportunity.confidence * 100))%")
                                .font(.subheadline.bold())
                        }
                        
                        HStack(spacing: 4) {
                            Text(opportunity.riskLevel.emoji)
                            Text(opportunity.riskLevel.rawValue)
                                .font(.subheadline.bold())
                                .foregroundColor(
                                    opportunity.riskLevel == .low ? .green :
                                    opportunity.riskLevel == .medium ? .orange : .red
                                )
                        }
                        
                        Spacer()
                        
                        if opportunity.requiresProTier {
                            HStack(spacing: 4) {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.purple)
                                Text("Pro")
                                    .font(.caption.bold())
                                    .foregroundColor(.purple)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
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
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse, options: .repeating.speed(0.5))
            
            Text("No opportunities found")
                .font(.headline)
            
            Text("Try adjusting your filters or search terms")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .opacity(viewAppeared ? 1 : 0)
        .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)
    }
    
    // MARK: - Computed Properties
    
    private var filteredOpportunities: [TaxDeductionOpportunity] {
        var filtered = opportunities
        
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText) ||
                $0.category.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        switch selectedFilter {
        case .all:
            break
        case .highSavings:
            filtered = filtered.filter { $0.estimatedSavings >= 500 }
        case .lowRisk:
            filtered = filtered.filter { $0.riskLevel == .low }
        case .actionable:
            filtered = filtered.filter {
                $0.riskLevel == .low &&
                $0.confidence >= 0.7 &&
                !$0.requiresProTier
            }
        }
        
        return filtered
    }
    
    private var sortedOpportunities: [TaxDeductionOpportunity] {
        filteredOpportunities.sorted { opp1, opp2 in
            switch sortOrder {
            case .savingsDescending:
                return opp1.estimatedSavings > opp2.estimatedSavings
            case .savingsAscending:
                return opp1.estimatedSavings < opp2.estimatedSavings
            case .riskAscending:
                return opp1.riskLevel.scoreImpact < opp2.riskLevel.scoreImpact
            case .riskDescending:
                return opp1.riskLevel.scoreImpact > opp2.riskLevel.scoreImpact
            }
        }
    }
    
    private var totalSavings: Double {
        filteredOpportunities.reduce(0) { $0 + $1.estimatedSavings }
    }
}

// MARK: - Preview Provider

#Preview {
    let sampleOpportunities = [
        TaxDeductionOpportunity(
            id: UUID(),
            category: .homeOffice,
            title: "Home Office Deduction",
            description: "You may qualify for a home office deduction based on your work patterns.",
            estimatedSavings: 2400,
            confidence: 0.8,
            riskLevel: .medium,
            actionItems: ["Measure office space", "Document exclusive use"],
            irsCitation: "IRS Publication 587",
            requiresProTier: false
        ),
        TaxDeductionOpportunity(
            id: UUID(),
            category: .vehicle,
            title: "Optimize Mileage Method",
            description: "Switching to actual expenses could save you money.",
            estimatedSavings: 850,
            confidence: 0.9,
            riskLevel: .low,
            actionItems: ["Track vehicle expenses", "Compare methods"],
            irsCitation: "IRS Publication 463",
            requiresProTier: false
        )
    ]
    
    DeductionOpportunitiesView(opportunities: sampleOpportunities)
}
