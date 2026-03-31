//  WatchHomeView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Watch Tab Navigation
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  TARGET MEMBERSHIP:
//  ✅ FLOWatch (watchOS app target)
//
//  NAVIGATION:
//  Uses TabView with .verticalPage style (watchOS native vertical paging).
//  Pages are ordered by frequency of use:
//  1. Today Summary — the "home" screen
//  2. Quick Expense — the hero feature
//  3. Mileage Control — Premium+ (shows upgrade prompt for free)
//  4. Tax Estimate — Premium+ (shows upgrade prompt for free)
//

import SwiftUI

struct WatchHomeView: View {
    
    @EnvironmentObject var session: WatchSessionManager
    @State private var selectedTab = 0
    
    var body: some View {
        Group {
            if session.hasData {
                // Main tab interface
                TabView(selection: $selectedTab) {
                    TodaySummaryView()
                        .tag(0)
                    
                    QuickExpenseView()
                        .tag(1)
                    
                    MileageControlView()
                        .tag(2)
                    
                    TaxEstimateView()
                        .tag(3)
                }
                .tabViewStyle(.verticalPage)
            } else {
                // Waiting for iPhone connection
                WatchLoadingView(isPhoneReachable: session.isPhoneReachable)
            }
        }
    }
}

// MARK: - Loading / No Data View

struct WatchLoadingView: View {
    let isPhoneReachable: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "iphone.and.arrow.forward")
                .font(.system(size: 32))
                .foregroundColor(.blue)
            
            Text("FLO")
                .font(.headline)
                .fontWeight(.bold)
            
            if isPhoneReachable {
                Text("Syncing...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                ProgressView()
                    .tint(.blue)
            } else {
                Text("Open FLO on\nyour iPhone")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

// MARK: - Upgrade Prompt (reusable)

/// Shown in place of Premium+ features for free tier users
struct WatchUpgradePrompt: View {
    let featureName: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(.orange)
            
            Text(featureName)
                .font(.caption)
                .fontWeight(.semibold)
            
            Text("Upgrade to Premium\non your iPhone")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Stale Data Indicator

/// Shows when snapshot is older than 5 minutes
struct StaleDataBanner: View {
    let lastUpdated: Date
    
    private var isStale: Bool {
        Date().timeIntervalSince(lastUpdated) > 300 // 5 minutes
    }
    
    var body: some View {
        if isStale {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.icloud")
                    .font(.caption2)
                Text("Updated \(lastUpdated, style: .relative) ago")
                    .font(.caption2)
            }
            .foregroundColor(.yellow)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
        }
    }
}

#Preview {
    WatchLoadingView(isPhoneReachable: false)
}
