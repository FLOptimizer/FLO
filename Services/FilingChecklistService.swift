//  FilingChecklistService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — Filing checklist generation from entity metadata
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Generates a list of required IRS forms, state filings, and deadlines
//  based on the user's business profiles, partners, and tax settings.
//

import Foundation
import SwiftData
import UserNotifications

// MARK: - Result Types

/// A single filing requirement with form, deadline, and context.
struct FilingRequirement: Identifiable {
    let id = UUID()
    let formName: String
    let formNumber: String
    let description: String
    let dueDate: Date?
    let dueDateDescription: String
    let category: FilingCategory
    let entityName: String?
    let isCompleted: Bool
    let priority: FilingPriority
    let icon: String

    enum FilingCategory: String, CaseIterable {
        case federalBusiness = "Federal Business"
        case federalPersonal = "Federal Personal"
        case state = "State"
        case informational = "Informational"
        case estimated = "Estimated Tax"

        var sortOrder: Int {
            switch self {
            case .federalBusiness: return 0
            case .federalPersonal: return 1
            case .state: return 2
            case .estimated: return 3
            case .informational: return 4
            }
        }
    }

    enum FilingPriority: Int, Comparable {
        case critical = 0  // Due within 30 days
        case upcoming = 1  // Due within 90 days
        case future = 2    // Due later

        static func < (lhs: FilingPriority, rhs: FilingPriority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        var displayName: String {
            switch self {
            case .critical: return "Due Soon"
            case .upcoming: return "Upcoming"
            case .future:   return "Future"
            }
        }

        var color: String {
            switch self {
            case .critical: return "red"
            case .upcoming: return "orange"
            case .future:   return "green"
            }
        }
    }
}

/// Complete filing checklist for a tax year.
struct FilingChecklist: Identifiable {
    let id = UUID()
    let taxYear: Int
    let requirements: [FilingRequirement]
    let generatedDate: Date

    var byCategory: [FilingRequirement.FilingCategory: [FilingRequirement]] {
        Dictionary(grouping: requirements) { $0.category }
    }

    var totalForms: Int { requirements.count }

    var criticalCount: Int {
        requirements.filter { $0.priority == .critical }.count
    }

    var upcomingCount: Int {
        requirements.filter { $0.priority == .upcoming }.count
    }
}

// MARK: - Service

@MainActor
final class FilingChecklistService {
    static let shared = FilingChecklistService()

    private init() {}

    // MARK: - Public API

    /// Generates a complete filing checklist for the given tax year.
    func generateChecklist(
        taxYear: Int,
        businesses: [BusinessProfile],
        taxSettings: TaxSettings?,
        referenceDate: Date = Date()
    ) -> FilingChecklist {
        var requirements: [FilingRequirement] = []

        let calendar = Calendar.current

        // --- Federal Business Returns ---
        for business in businesses where business.isActive {
            requirements.append(contentsOf: businessFilings(
                for: business,
                taxYear: taxYear,
                calendar: calendar,
                referenceDate: referenceDate
            ))

            // K-1s for partnerships
            if business.isPartnership {
                requirements.append(contentsOf: partnerK1Filings(
                    for: business,
                    taxYear: taxYear,
                    calendar: calendar,
                    referenceDate: referenceDate
                ))
            }

            // State business return
            if let state = business.state, !state.isEmpty {
                requirements.append(contentsOf: stateBusinessFilings(
                    for: business,
                    state: state,
                    taxYear: taxYear,
                    calendar: calendar,
                    referenceDate: referenceDate
                ))
            }
        }

        // --- Federal Personal Return ---
        requirements.append(contentsOf: personalFilings(
            taxYear: taxYear,
            filingStatus: taxSettings?.filingStatus ?? .single,
            calendar: calendar,
            referenceDate: referenceDate
        ))

        // --- State Personal Return ---
        if let state = taxSettings?.state, !TaxSettings.noIncomeTaxStates.contains(state) {
            requirements.append(contentsOf: statePersonalFilings(
                state: state,
                taxYear: taxYear,
                calendar: calendar,
                referenceDate: referenceDate
            ))
        }

        // --- Quarterly Estimated Tax ---
        requirements.append(contentsOf: estimatedTaxFilings(
            taxYear: taxYear,
            calendar: calendar,
            referenceDate: referenceDate
        ))

        // Sort by category, then priority, then due date
        let sorted = requirements.sorted { a, b in
            if a.category.sortOrder != b.category.sortOrder {
                return a.category.sortOrder < b.category.sortOrder
            }
            if a.priority != b.priority {
                return a.priority < b.priority
            }
            if let da = a.dueDate, let db = b.dueDate {
                return da < db
            }
            return false
        }

        return FilingChecklist(
            taxYear: taxYear,
            requirements: sorted,
            generatedDate: referenceDate
        )
    }

    // MARK: - Business Filings

    private func businessFilings(
        for business: BusinessProfile,
        taxYear: Int,
        calendar: Calendar,
        referenceDate: Date
    ) -> [FilingRequirement] {
        var filings: [FilingRequirement] = []

        switch business.businessType {
        case .soleProprietorship, .other:
            // Schedule C filed with personal 1040 — April 15
            let dueDate = Self.aprilDeadline(taxYear: taxYear, calendar: calendar)
            filings.append(FilingRequirement(
                formName: "Schedule C",
                formNumber: "1040 Schedule C",
                description: "Profit or Loss From Business",
                dueDate: dueDate,
                dueDateDescription: "April 15, \(taxYear + 1)",
                category: .federalBusiness,
                entityName: business.businessName,
                isCompleted: false,
                priority: priority(for: dueDate, referenceDate: referenceDate),
                icon: "doc.text.fill"
            ))

            // Schedule SE (Self-Employment Tax)
            filings.append(FilingRequirement(
                formName: "Schedule SE",
                formNumber: "1040 Schedule SE",
                description: "Self-Employment Tax",
                dueDate: dueDate,
                dueDateDescription: "April 15, \(taxYear + 1) (with 1040)",
                category: .federalBusiness,
                entityName: business.businessName,
                isCompleted: false,
                priority: priority(for: dueDate, referenceDate: referenceDate),
                icon: "dollarsign.circle.fill"
            ))

        case .llc, .partnership:
            // Form 1065 — March 15
            let dueDate = Self.marchDeadline(taxYear: taxYear, calendar: calendar)
            filings.append(FilingRequirement(
                formName: "Form 1065",
                formNumber: "1065",
                description: "U.S. Return of Partnership Income",
                dueDate: dueDate,
                dueDateDescription: "March 15, \(taxYear + 1)",
                category: .federalBusiness,
                entityName: business.businessName,
                isCompleted: false,
                priority: priority(for: dueDate, referenceDate: referenceDate),
                icon: "building.2.fill"
            ))

        case .farm:
            // Schedule F filed with personal 1040 — April 15
            // (Or March 1 if not paying estimated tax)
            let dueDate = Self.aprilDeadline(taxYear: taxYear, calendar: calendar)
            filings.append(FilingRequirement(
                formName: "Schedule F",
                formNumber: "1040 Schedule F",
                description: "Profit or Loss From Farming",
                dueDate: dueDate,
                dueDateDescription: "April 15, \(taxYear + 1)",
                category: .federalBusiness,
                entityName: business.businessName,
                isCompleted: false,
                priority: priority(for: dueDate, referenceDate: referenceDate),
                icon: "leaf.fill"
            ))

        case .rentalProperty:
            // Schedule E filed with personal 1040 — April 15
            let dueDate = Self.aprilDeadline(taxYear: taxYear, calendar: calendar)
            filings.append(FilingRequirement(
                formName: "Schedule E",
                formNumber: "1040 Schedule E",
                description: "Supplemental Income and Loss",
                dueDate: dueDate,
                dueDateDescription: "April 15, \(taxYear + 1)",
                category: .federalBusiness,
                entityName: business.businessName,
                isCompleted: false,
                priority: priority(for: dueDate, referenceDate: referenceDate),
                icon: "house.fill"
            ))
        }

        // Depreciation form if business has assets
        if !business.activeAssets.isEmpty {
            let dueDate = business.isPartnership
                ? Self.marchDeadline(taxYear: taxYear, calendar: calendar)
                : Self.aprilDeadline(taxYear: taxYear, calendar: calendar)
            filings.append(FilingRequirement(
                formName: "Form 4562",
                formNumber: "4562",
                description: "Depreciation and Amortization",
                dueDate: dueDate,
                dueDateDescription: "With entity return",
                category: .federalBusiness,
                entityName: business.businessName,
                isCompleted: false,
                priority: priority(for: dueDate, referenceDate: referenceDate),
                icon: "chart.bar.fill"
            ))
        }

        return filings
    }

    // MARK: - Partner K-1 Filings

    private func partnerK1Filings(
        for business: BusinessProfile,
        taxYear: Int,
        calendar: Calendar,
        referenceDate: Date
    ) -> [FilingRequirement] {
        let partners = business.sortedPartners
        guard !partners.isEmpty else { return [] }

        let dueDate = Self.marchDeadline(taxYear: taxYear, calendar: calendar)

        return partners.map { partner in
            FilingRequirement(
                formName: "Schedule K-1 (\(partner.partnerName))",
                formNumber: "1065 Schedule K-1",
                description: "Partner's Share of Income — \(partner.ownershipDisplay)",
                dueDate: dueDate,
                dueDateDescription: "March 15, \(taxYear + 1) (with 1065)",
                category: .informational,
                entityName: business.businessName,
                isCompleted: false,
                priority: priority(for: dueDate, referenceDate: referenceDate),
                icon: "person.fill"
            )
        }
    }

    // MARK: - State Business Filings

    private func stateBusinessFilings(
        for business: BusinessProfile,
        state: String,
        taxYear: Int,
        calendar: Calendar,
        referenceDate: Date
    ) -> [FilingRequirement] {
        // No state income tax states
        guard !TaxSettings.noIncomeTaxStates.contains(state) else { return [] }

        let stateName = Self.stateAbbreviationToName[state] ?? state

        if business.isPartnership {
            let dueDate = Self.marchDeadline(taxYear: taxYear, calendar: calendar)
            return [FilingRequirement(
                formName: "\(stateName) Partnership Return",
                formNumber: "\(state) PTE Return",
                description: "State partnership/LLC return for \(stateName)",
                dueDate: dueDate,
                dueDateDescription: "March 15, \(taxYear + 1) (varies by state)",
                category: .state,
                entityName: business.businessName,
                isCompleted: false,
                priority: priority(for: dueDate, referenceDate: referenceDate),
                icon: "flag.fill"
            )]
        }

        // Sole props/farms file state return with personal
        return []
    }

    // MARK: - Personal Filings

    private func personalFilings(
        taxYear: Int,
        filingStatus: TaxSettings.FilingStatus,
        calendar: Calendar,
        referenceDate: Date
    ) -> [FilingRequirement] {
        let dueDate = Self.aprilDeadline(taxYear: taxYear, calendar: calendar)

        return [
            FilingRequirement(
                formName: "Form 1040",
                formNumber: "1040",
                description: "U.S. Individual Income Tax Return (\(filingStatus.displayName))",
                dueDate: dueDate,
                dueDateDescription: "April 15, \(taxYear + 1)",
                category: .federalPersonal,
                entityName: nil,
                isCompleted: false,
                priority: priority(for: dueDate, referenceDate: referenceDate),
                icon: "person.crop.rectangle.fill"
            )
        ]
    }

    // MARK: - State Personal Filings

    private func statePersonalFilings(
        state: String,
        taxYear: Int,
        calendar: Calendar,
        referenceDate: Date
    ) -> [FilingRequirement] {
        let stateName = Self.stateAbbreviationToName[state] ?? state
        let dueDate = Self.aprilDeadline(taxYear: taxYear, calendar: calendar)

        return [
            FilingRequirement(
                formName: "\(stateName) Individual Return",
                formNumber: "\(state) Individual",
                description: "State individual income tax return",
                dueDate: dueDate,
                dueDateDescription: "April 15, \(taxYear + 1) (most states)",
                category: .state,
                entityName: nil,
                isCompleted: false,
                priority: priority(for: dueDate, referenceDate: referenceDate),
                icon: "flag.fill"
            )
        ]
    }

    // MARK: - Estimated Tax

    private func estimatedTaxFilings(
        taxYear: Int,
        calendar: Calendar,
        referenceDate: Date
    ) -> [FilingRequirement] {
        let deadlines = TaxSettings.quarterlyDeadlines(for: taxYear)
        guard deadlines.count == 4 else { return [] }

        let quarterLabels = ["Q1 (Jan–Mar)", "Q2 (Apr–May)", "Q3 (Jun–Aug)", "Q4 (Sep–Dec)"]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d, yyyy"

        return zip(quarterLabels, deadlines).map { label, deadline in
            FilingRequirement(
                formName: "1040-ES \(label)",
                formNumber: "1040-ES",
                description: "Quarterly estimated tax payment",
                dueDate: deadline,
                dueDateDescription: dateFormatter.string(from: deadline),
                category: .estimated,
                entityName: nil,
                isCompleted: deadline < referenceDate,
                priority: priority(for: deadline, referenceDate: referenceDate),
                icon: "calendar.badge.clock"
            )
        }
    }

    // MARK: - Helpers

    private func priority(for dueDate: Date?, referenceDate: Date) -> FilingRequirement.FilingPriority {
        guard let dueDate else { return .future }
        let days = Calendar.current.dateComponents([.day], from: referenceDate, to: dueDate).day ?? 365
        if days < 0 { return .critical } // Past due
        if days <= 30 { return .critical }
        if days <= 90 { return .upcoming }
        return .future
    }

    /// March 15 of the year after tax year (partnership returns)
    static func marchDeadline(taxYear: Int, calendar: Calendar) -> Date? {
        calendar.date(from: DateComponents(year: taxYear + 1, month: 3, day: 15))
    }

    /// April 15 of the year after tax year (individual/sole prop returns)
    static func aprilDeadline(taxYear: Int, calendar: Calendar) -> Date? {
        calendar.date(from: DateComponents(year: taxYear + 1, month: 4, day: 15))
    }

    // MARK: - Deadline Notifications

    /// Schedule push notifications for upcoming tax deadlines.
    /// Schedules alerts at 30 days and 7 days before each deadline.
    func scheduleDeadlineNotifications(for checklist: FilingChecklist) async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let calendar = Calendar.current
        let now = Date()

        for requirement in checklist.requirements {
            guard let dueDate = requirement.dueDate else { continue }
            guard dueDate > now else { continue }

            // Schedule 30-day and 7-day reminders
            for daysBefore in [30, 7] {
                guard let triggerDate = calendar.date(byAdding: .day, value: -daysBefore, to: dueDate) else { continue }
                guard triggerDate > now else { continue }

                let dedupKey = "tax.deadline.\(requirement.formNumber).\(checklist.taxYear).\(daysBefore)"
                guard !UserDefaults.standard.bool(forKey: dedupKey) else { continue }

                let content = UNMutableNotificationContent()
                content.title = "Tax Deadline in \(daysBefore) Days"
                content.body = "\(requirement.formNumber) (\(requirement.formName)) due \(dueDate.formatted(date: .abbreviated, time: .omitted))"
                content.sound = .default
                content.categoryIdentifier = "TAX_DEADLINE"
                content.userInfo = [
                    "type": "tax_deadline",
                    "formNumber": requirement.formNumber,
                    "daysBefore": daysBefore
                ]

                let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour], from: triggerDate)
                var adjustedComponents = triggerComponents
                adjustedComponents.hour = 9 // 9 AM local time

                let trigger = UNCalendarNotificationTrigger(dateMatching: adjustedComponents, repeats: false)
                let identifier = "tax_deadline_\(requirement.formNumber)_\(checklist.taxYear)_\(daysBefore)"

                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

                do {
                    try await UNUserNotificationCenter.current().add(request)
                    UserDefaults.standard.set(true, forKey: dedupKey)
                    #if DEBUG
                    print("📋 Tax deadline notification scheduled: \(requirement.formNumber) in \(daysBefore) days")
                    #endif
                } catch {
                    #if DEBUG
                    print("❌ Tax deadline notification error: \(error)")
                    #endif
                }
            }
        }
    }

    /// Notification categories for tax deadline alerts.
    func configureDeadlineNotificationCategories() -> [UNNotificationCategory] {
        let viewAction = UNNotificationAction(
            identifier: "VIEW_CHECKLIST",
            title: "View Checklist",
            options: [.foreground]
        )
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS_DEADLINE",
            title: "Dismiss",
            options: [.destructive]
        )
        return [UNNotificationCategory(
            identifier: "TAX_DEADLINE",
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )]
    }

    /// Remove all pending tax deadline notifications.
    func cancelAllDeadlineNotifications() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let taxIds = requests
                .filter { $0.identifier.hasPrefix("tax_deadline_") }
                .map { $0.identifier }
            center.removePendingNotificationRequests(withIdentifiers: taxIds)
            #if DEBUG
            print("📋 Cancelled \(taxIds.count) tax deadline notification(s)")
            #endif
        }
    }

    /// State abbreviation to full name
    static let stateAbbreviationToName: [String: String] = [
        "AL": "Alabama", "AK": "Alaska", "AZ": "Arizona", "AR": "Arkansas",
        "CA": "California", "CO": "Colorado", "CT": "Connecticut", "DE": "Delaware",
        "FL": "Florida", "GA": "Georgia", "HI": "Hawaii", "ID": "Idaho",
        "IL": "Illinois", "IN": "Indiana", "IA": "Iowa", "KS": "Kansas",
        "KY": "Kentucky", "LA": "Louisiana", "ME": "Maine", "MD": "Maryland",
        "MA": "Massachusetts", "MI": "Michigan", "MN": "Minnesota", "MS": "Mississippi",
        "MO": "Missouri", "MT": "Montana", "NE": "Nebraska", "NV": "Nevada",
        "NH": "New Hampshire", "NJ": "New Jersey", "NM": "New Mexico", "NY": "New York",
        "NC": "North Carolina", "ND": "North Dakota", "OH": "Ohio", "OK": "Oklahoma",
        "OR": "Oregon", "PA": "Pennsylvania", "RI": "Rhode Island", "SC": "South Carolina",
        "SD": "South Dakota", "TN": "Tennessee", "TX": "Texas", "UT": "Utah",
        "VT": "Vermont", "VA": "Virginia", "WA": "Washington", "WV": "West Virginia",
        "WI": "Wisconsin", "WY": "Wyoming", "DC": "District of Columbia"
    ]
}
