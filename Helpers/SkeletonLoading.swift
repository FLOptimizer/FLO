//  SkeletonLoading.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Skeleton Loading States
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  FEATURES:
//  ✅ Pre-built skeleton components for common views
//  ✅ Customizable shapes and sizes
//  ✅ Uses existing floShimmer() from AnimationService
//  ✅ Smooth transitions from skeleton to content
//
//  NOTE: Shimmer modifier is defined in AnimationService.swift
//  Use .floShimmer(isActive: true) for shimmer effect
//
//  USAGE:
//  1. Use pre-built skeletons:
//     if isLoading {
//         TransactionRowSkeleton()
//     } else {
//         TransactionRow(transaction: transaction)
//     }
//
//  2. Create custom skeleton shapes:
//     SkeletonShape()
//         .frame(width: 100, height: 20)
//

import SwiftUI

// MARK: - Skeleton Shape

struct SkeletonShape: View {
    var cornerRadius: CGFloat = 4
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(.systemGray5))
            .floShimmer()
    }
}

// MARK: - Skeleton Circle

struct SkeletonCircle: View {
    var size: CGFloat = 40
    
    var body: some View {
        Circle()
            .fill(Color(.systemGray5))
            .frame(width: size, height: size)
            .floShimmer()
    }
}

// MARK: - Transaction Row Skeleton

struct TransactionRowSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            // Category icon placeholder
            SkeletonCircle(size: 40)
            
            // Text content
            VStack(alignment: .leading, spacing: 6) {
                // Title
                SkeletonShape()
                    .frame(width: 140, height: 14)
                
                // Subtitle
                SkeletonShape()
                    .frame(width: 100, height: 12)
            }
            
            Spacer()
            
            // Amount
            VStack(alignment: .trailing, spacing: 6) {
                SkeletonShape()
                    .frame(width: 70, height: 14)
                
                SkeletonShape()
                    .frame(width: 50, height: 12)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Invoice Row Skeleton

struct InvoiceRowSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            SkeletonShape(cornerRadius: 8)
                .frame(width: 44, height: 44)
            
            // Invoice details
            VStack(alignment: .leading, spacing: 6) {
                // Client name
                SkeletonShape()
                    .frame(width: 120, height: 14)
                
                // Invoice number
                SkeletonShape()
                    .frame(width: 80, height: 12)
                
                // Date
                SkeletonShape()
                    .frame(width: 100, height: 10)
            }
            
            Spacer()
            
            // Amount
            SkeletonShape()
                .frame(width: 80, height: 16)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Budget Row Skeleton

struct BudgetRowSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Category icon
                SkeletonCircle(size: 32)
                
                // Category name
                SkeletonShape()
                    .frame(width: 100, height: 14)
                
                Spacer()
                
                // Amount
                SkeletonShape()
                    .frame(width: 80, height: 14)
            }
            
            // Progress bar
            SkeletonShape(cornerRadius: 4)
                .frame(height: 8)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Mileage Trip Skeleton

struct MileageTripSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            // Purpose icon
            SkeletonCircle(size: 36)
            
            // Trip details
            VStack(alignment: .leading, spacing: 6) {
                // Purpose
                SkeletonShape()
                    .frame(width: 100, height: 14)
                
                // Addresses
                SkeletonShape()
                    .frame(width: 160, height: 12)
                
                // Date
                SkeletonShape()
                    .frame(width: 120, height: 10)
            }
            
            Spacer()
            
            // Miles & Deduction
            VStack(alignment: .trailing, spacing: 6) {
                SkeletonShape()
                    .frame(width: 60, height: 14)
                
                SkeletonShape()
                    .frame(width: 50, height: 12)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Dashboard Card Skeleton

struct DashboardCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                SkeletonCircle(size: 24)
                SkeletonShape()
                    .frame(width: 120, height: 14)
                Spacer()
            }
            
            // Main value
            SkeletonShape()
                .frame(width: 150, height: 28)
            
            // Subtitle
            SkeletonShape()
                .frame(width: 100, height: 12)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Statistics Card Skeleton

struct StatisticsCardSkeleton: View {
    var body: some View {
        HStack(spacing: 16) {
            ForEach(0..<3, id: \.self) { _ in
                VStack(spacing: 6) {
                    SkeletonCircle(size: 24)
                    SkeletonShape()
                        .frame(width: 60, height: 16)
                    SkeletonShape()
                        .frame(width: 40, height: 10)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Client Row Skeleton

struct ClientRowSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            SkeletonCircle(size: 44)
            
            // Details
            VStack(alignment: .leading, spacing: 6) {
                SkeletonShape()
                    .frame(width: 140, height: 14)
                
                SkeletonShape()
                    .frame(width: 180, height: 12)
            }
            
            Spacer()
            
            // Chevron placeholder
            SkeletonShape()
                .frame(width: 8, height: 14)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - List Skeleton Wrapper

struct SkeletonList<Content: View>: View {
    let count: Int
    let content: () -> Content
    
    init(count: Int = 5, @ViewBuilder content: @escaping () -> Content) {
        self.count = count
        self.content = content
    }
    
    var body: some View {
        ForEach(0..<count, id: \.self) { index in
            content()
                .opacity(1.0 - (Double(index) * 0.1))
        }
    }
}

// MARK: - Skeleton Loading View Modifier

struct SkeletonLoadingModifier<Skeleton: View>: ViewModifier {
    let isLoading: Bool
    let skeleton: () -> Skeleton
    
    func body(content: Content) -> some View {
        if isLoading {
            skeleton()
                .transition(.opacity)
        } else {
            content
                .transition(.opacity)
        }
    }
}

extension View {
    /// Shows a skeleton view while loading
    func skeleton<S: View>(
        isLoading: Bool,
        @ViewBuilder skeleton: @escaping () -> S
    ) -> some View {
        modifier(SkeletonLoadingModifier(isLoading: isLoading, skeleton: skeleton))
    }
}

// MARK: - Animated Transition Helper

struct SkeletonTransition: ViewModifier {
    let isLoading: Bool
    
    func body(content: Content) -> some View {
        content
            .animation(FLOAnimation.standard, value: isLoading)
    }
}

extension View {
    /// Animates transition between skeleton and content
    func skeletonTransition(isLoading: Bool) -> some View {
        modifier(SkeletonTransition(isLoading: isLoading))
    }
}

// MARK: - Previews

#Preview("Transaction Skeletons") {
    List {
        Section("Loading") {
            SkeletonList(count: 3) {
                TransactionRowSkeleton()
            }
        }
    }
}

#Preview("Invoice Skeletons") {
    List {
        Section("Loading") {
            SkeletonList(count: 3) {
                InvoiceRowSkeleton()
            }
        }
    }
}

#Preview("Budget Skeletons") {
    List {
        Section("Loading") {
            SkeletonList(count: 3) {
                BudgetRowSkeleton()
            }
        }
    }
}

#Preview("Mileage Skeletons") {
    List {
        Section("Loading") {
            SkeletonList(count: 3) {
                MileageTripSkeleton()
            }
        }
    }
}

#Preview("Dashboard Cards") {
    VStack(spacing: 16) {
        DashboardCardSkeleton()
        StatisticsCardSkeleton()
    }
    .padding()
}

#Preview("All Skeletons") {
    ScrollView {
        VStack(spacing: 20) {
            Text("Transaction").font(.headline)
            TransactionRowSkeleton()
                .padding(.horizontal)
            
            Divider()
            
            Text("Invoice").font(.headline)
            InvoiceRowSkeleton()
                .padding(.horizontal)
            
            Divider()
            
            Text("Budget").font(.headline)
            BudgetRowSkeleton()
                .padding(.horizontal)
            
            Divider()
            
            Text("Mileage Trip").font(.headline)
            MileageTripSkeleton()
                .padding(.horizontal)
            
            Divider()
            
            Text("Client").font(.headline)
            ClientRowSkeleton()
                .padding(.horizontal)
            
            Divider()
            
            Text("Dashboard Card").font(.headline)
            DashboardCardSkeleton()
                .padding(.horizontal)
            
            Divider()
            
            Text("Statistics Card").font(.headline)
            StatisticsCardSkeleton()
                .padding(.horizontal)
        }
        .padding(.vertical)
    }
}
