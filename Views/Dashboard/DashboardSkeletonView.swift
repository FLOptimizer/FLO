//  DashboardSkeletonView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1.1 - Accessibility: verified VoiceOver hiding + loading announcement
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.1:
//  ✅ Entire skeleton hidden from VoiceOver
//  ✅ "Loading" announcement for screen readers
//
//  FEATURES:
//  - Complete skeleton for dashboard initial load
//  - Matches dashboard card layout exactly
//  ✅ Uses floShimmer() from AnimationService
//  ✅ Smooth transition to real content
//
//  USAGE:
//  In DashboardView, wrap content:
//  if isInitialLoad {
//      DashboardSkeletonView()
//  } else {
//      // Real dashboard content
//  }
//

import SwiftUI

struct DashboardSkeletonView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Finance Mode Selector Skeleton
                financeModeSkeletonSelector
                
                // Timeframe Picker Skeleton
                timeframePickerSkeleton
                
                // Balance Summary Card Skeleton
                BalanceSummaryCardSkeleton()
                    .padding(.horizontal)
                
                // Quick Actions Skeleton
                QuickActionsSkeletonView()
                    .padding(.horizontal)
                
                // Budget Overview Skeleton
                BudgetOverviewCardSkeleton()
                    .padding(.horizontal)
                
                // Recent Transactions Skeleton
                RecentTransactionsCardSkeleton()
                    .padding(.horizontal)
                
                Color.clear.frame(height: 20)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        // v1.1: Hide skeleton from VoiceOver
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading dashboard")
        .onAppear {
            AccessibilityAnnouncement.announce("Loading dashboard")
        }
    }
    
    // MARK: - Finance Mode Skeleton
    
    private var financeModeSkeletonSelector: some View {
        VStack(spacing: 8) {
            // Segmented control skeleton
            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonShape(cornerRadius: 8)
                        .frame(height: 32)
                }
            }
            .padding(.horizontal)
            
            // Description skeleton
            SkeletonShape()
                .frame(width: 200, height: 12)
                .padding(.horizontal)
        }
    }
    
    // MARK: - Timeframe Picker Skeleton
    
    private var timeframePickerSkeleton: some View {
        HStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { _ in
                SkeletonShape(cornerRadius: 8)
                    .frame(height: 32)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Balance Summary Card Skeleton

struct BalanceSummaryCardSkeleton: View {
    var body: some View {
        VStack(spacing: 16) {
            // Net Income
            VStack(spacing: 4) {
                SkeletonShape()
                    .frame(width: 80, height: 12)
                SkeletonShape()
                    .frame(width: 150, height: 36)
            }
            
            Divider()
            
            // Income / Expenses Row
            HStack {
                // Income
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        SkeletonCircle(size: 16)
                        SkeletonShape()
                            .frame(width: 50, height: 12)
                    }
                    SkeletonShape()
                        .frame(width: 80, height: 20)
                }
                
                Spacer()
                
                // Expenses
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        SkeletonCircle(size: 16)
                        SkeletonShape()
                            .frame(width: 60, height: 12)
                    }
                    SkeletonShape()
                        .frame(width: 80, height: 20)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Quick Actions Skeleton

struct QuickActionsSkeletonView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                SkeletonCircle(size: 24)
                SkeletonShape()
                    .frame(width: 100, height: 16)
                Spacer()
                SkeletonShape()
                    .frame(width: 80, height: 12)
            }
            .padding()
            
            Divider()
            
            // Buttons
            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    QuickActionButtonSkeleton()
                }
            }
            .padding()
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct QuickActionButtonSkeleton: View {
    var body: some View {
        VStack(spacing: 6) {
            SkeletonCircle(size: 48)
            SkeletonShape()
                .frame(width: 50, height: 10)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Budget Overview Card Skeleton

struct BudgetOverviewCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                SkeletonShape()
                    .frame(width: 100, height: 16)
                Spacer()
                SkeletonShape()
                    .frame(width: 60, height: 14)
            }
            
            // Budget items
            ForEach(0..<3, id: \.self) { _ in
                BudgetItemSkeleton()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct BudgetItemSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SkeletonCircle(size: 24)
                SkeletonShape()
                    .frame(width: 80, height: 14)
                Spacer()
                SkeletonShape()
                    .frame(width: 60, height: 14)
            }
            
            // Progress bar
            SkeletonShape(cornerRadius: 4)
                .frame(height: 6)
        }
    }
}

// MARK: - Recent Transactions Card Skeleton

struct RecentTransactionsCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                SkeletonShape()
                    .frame(width: 140, height: 16)
                Spacer()
                SkeletonShape()
                    .frame(width: 50, height: 14)
            }
            
            // Transaction items
            ForEach(0..<4, id: \.self) { index in
                TransactionRowSkeleton()
                    .opacity(1.0 - (Double(index) * 0.15))
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Tax Estimate Card Skeleton (for Business mode)

struct TaxEstimateCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                SkeletonCircle(size: 24)
                SkeletonShape()
                    .frame(width: 120, height: 16)
                Spacer()
            }
            
            // Main estimate
            VStack(alignment: .leading, spacing: 4) {
                SkeletonShape()
                    .frame(width: 100, height: 12)
                SkeletonShape()
                    .frame(width: 140, height: 32)
            }
            
            Divider()
            
            // Breakdown
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    SkeletonShape()
                        .frame(width: 80, height: 10)
                    SkeletonShape()
                        .frame(width: 60, height: 14)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    SkeletonShape()
                        .frame(width: 80, height: 10)
                    SkeletonShape()
                        .frame(width: 60, height: 14)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Mileage Card Skeleton

struct MileageCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                SkeletonCircle(size: 24)
                SkeletonShape()
                    .frame(width: 100, height: 16)
                Spacer()
                SkeletonShape()
                    .frame(width: 70, height: 24)
            }
            
            // Stats row
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    SkeletonShape()
                        .frame(width: 60, height: 10)
                    SkeletonShape()
                        .frame(width: 80, height: 18)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    SkeletonShape()
                        .frame(width: 70, height: 10)
                    SkeletonShape()
                        .frame(width: 90, height: 18)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview("Dashboard Skeleton") {
    NavigationStack {
        DashboardSkeletonView()
            .navigationTitle("Dashboard")
    }
}

#Preview("Individual Components") {
    ScrollView {
        VStack(spacing: 20) {
            Text("Balance Summary").font(.headline)
            BalanceSummaryCardSkeleton()
            
            Divider()
            
            Text("Quick Actions").font(.headline)
            QuickActionsSkeletonView()
            
            Divider()
            
            Text("Budget Overview").font(.headline)
            BudgetOverviewCardSkeleton()
            
            Divider()
            
            Text("Recent Transactions").font(.headline)
            RecentTransactionsCardSkeleton()
            
            Divider()
            
            Text("Tax Estimate").font(.headline)
            TaxEstimateCardSkeleton()
            
            Divider()
            
            Text("Mileage").font(.headline)
            MileageCardSkeleton()
        }
        .padding()
    }
}
