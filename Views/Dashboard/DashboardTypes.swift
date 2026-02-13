//  DashboardTypes.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Shared Dashboard Types
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CONTENTS:
//  - FinanceMode enum (Business/Personal/All)
//  - Timeframe enum (This Week/Month/Year)
//  - Notification.Name extensions for dashboard
//
//  These types are used across multiple dashboard components.
//

import SwiftUI

// MARK: - Finance Mode

/// The primary differentiator for FLO - Business vs Personal finance tracking
enum FinanceMode: String, CaseIterable {
    case business = "Business"
    case personal = "Personal"
    case all = "All"
    
    var icon: String {
        switch self {
        case .business: return "briefcase.fill"
        case .personal: return "person.fill"
        case .all: return "rectangle.grid.1x2.fill"
        }
    }
    
    var description: String {
        switch self {
        case .business: return "Tax-deductible business expenses"
        case .personal: return "Personal spending"
        case .all: return "Complete financial picture"
        }
    }
    
    var color: Color {
        switch self {
        case .business: return .businessColor
        case .personal: return .personalColor
        case .all: return Color.brandPrimary
        }
    }
}

// MARK: - Timeframe

/// Time period filter for dashboard data
enum Timeframe: String, CaseIterable {
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case thisYear = "This Year"
    
    var displayName: String {
        self.rawValue
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let dashboardMileageTripCompleted = Notification.Name("dashboardMileageTripCompleted")
}
