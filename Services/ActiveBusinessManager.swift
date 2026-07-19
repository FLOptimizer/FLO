//  ActiveBusinessManager.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Multi-Business UI State Manager
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Manages which business is currently selected in the UI.
//  Used by DashboardView, ReportView, and other business-filtered views.
//

import Foundation
import SwiftUI

/// Manages the active business context for the UI
@MainActor
@Observable
class ActiveBusinessManager {
    static let shared = ActiveBusinessManager()

    /// Currently selected business (nil = "All Businesses" view)
    var activeBusiness: BusinessProfile?

    /// Current view mode derived from selection
    var viewMode: ViewMode {
        if let business = activeBusiness {
            return .specificBusiness(business)
        }
        return .allBusinesses
    }

    /// Whether we're showing personal-only mode
    var isPersonalMode: Bool = false

    /// View mode for business-aware filtering
    enum ViewMode {
        case allBusinesses
        case specificBusiness(BusinessProfile)
        case personal
    }

    /// Effective view mode considering personal toggle
    var effectiveViewMode: ViewMode {
        if isPersonalMode {
            return .personal
        }
        return viewMode
    }

    /// Display name for the current selection
    var displayName: String {
        if isPersonalMode {
            return "Personal"
        }
        return activeBusiness?.businessName ?? "All Businesses"
    }

    /// Display icon for the current selection
    var displayIcon: String {
        if isPersonalMode {
            return "person.fill"
        }
        return activeBusiness?.displayIcon ?? "building.2"
    }

    /// Select a specific business
    func selectBusiness(_ business: BusinessProfile) {
        isPersonalMode = false
        activeBusiness = business
    }

    /// Select "All Businesses" mode
    func selectAllBusinesses() {
        isPersonalMode = false
        activeBusiness = nil
    }

    /// Select "Personal" mode
    func selectPersonal() {
        isPersonalMode = true
        activeBusiness = nil
    }

    private init() {}
}
