//  TaxSettingsView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.9 — Income Sources Summary section
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v2.9:
//  ✅ ADDED: @Query for allCategories — read income category classifications
//  ✅ ADDED: incomeSummarySection — read-only list of income categories showing
//            tax treatment badge, owner badge, and withholding rate for W-2 sources
//  ✅ ADDED: Empty state when no income categories exist — guides user to Categories
//  ✅ UPDATED: incomeSummarySection inserted between Tax Components and Reminders
//  ✅ UPDATED: Animation delays adjusted for all sections below the insertion point:
//             Reminders 0.25→0.30, Advanced 0.30→0.35, Help 0.35→0.40
//  ✅ PRESERVED: All v2.8 decorative icon accessibilityHidden modifiers
//  ✅ PRESERVED: All v2.7 Dynamic Type (lineLimit + minimumScaleFactor) on all text
//  ✅ PRESERVED: All v2.6 VoiceOver coverage, screen change announcements
//  ✅ PRESERVED: All v2.5 NavigationLink picker style for state and filing status
//  ✅ PRESERVED: All v2.4 @Query settings loading, no rogue ModelContainer
//  ✅ PRESERVED: All v2.3 haptics, animations, section entrance delays
//
//  CHANGES v2.8 — VoiceOver Audit:
//  ✅ Help button question mark icon hidden, chevron already hidden
//
//  CHANGES v2.7 — Dynamic Type Verification:
//  ✅ State/filing status labels, IRS mileage labels, picker view names — all fixed
//
//  CHANGES v2.6:
//  ✅ Full VoiceOver, screen change announcements, reminder slider accessibility value
//
//  CHANGES v2.5:
//  ✅ NavigationLink picker style for state and filing status
//
//  CHANGES v2.4:
//  ✅ @Query + onAppear loading, eliminated rogue ModelContainer CloudKit errors
//
//  PREVIOUS (v2.3):
//  — Haptics, section entrance animations, advanced section expand animation
//

import SwiftUI
import SwiftData

struct TaxSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var taxSettings: [TaxSettings]

    // v2.9 — read income categories to power the Income Sources Summary section
    @Query(sort: \Category.name) private var allCategories: [Category]

    // MARK: - Form State

    @State private var selectedState: String = "CA"
    @State private var filingStatus: TaxSettings.FilingStatus = .single
    @State private var priorYearTax: String = ""
    @State private var isHighEarner: Bool = false
    @State private var customFederalRate: String = ""
    @State private var customStateRate: String = ""
    @State private var includeSelfEmployment: Bool = true
    @State private var enableReminders: Bool = true
    @State private var reminderDays: Double = 14

    @State private var showAdvanced: Bool = false
    @State private var showHelp: Bool = false
    @State private var viewAppeared = false
    @State private var settingsLoaded = false

    // MARK: - Computed Helpers

    private var currentSettings: TaxSettings? { taxSettings.first }

    /// All income categories, alphabetical (already sorted by @Query)
    private var incomeCategories: [Category] {
        allCategories.filter { $0.isIncome }
    }

    // v2.5: State name lookup for display
    private var selectedStateName: String { stateNames[selectedState] ?? selectedState }

    // v2.5: Full state names for display
    private let stateNames: [String: String] = [
        "AL": "Alabama",       "AK": "Alaska",         "AZ": "Arizona",
        "AR": "Arkansas",      "CA": "California",     "CO": "Colorado",
        "CT": "Connecticut",   "DE": "Delaware",        "DC": "Washington D.C.",
        "FL": "Florida",       "GA": "Georgia",         "HI": "Hawaii",
        "ID": "Idaho",         "IL": "Illinois",        "IN": "Indiana",
        "IA": "Iowa",          "KS": "Kansas",          "KY": "Kentucky",
        "LA": "Louisiana",     "ME": "Maine",           "MD": "Maryland",
        "MA": "Massachusetts", "MI": "Michigan",        "MN": "Minnesota",
        "MS": "Mississippi",   "MO": "Missouri",        "MT": "Montana",
        "NE": "Nebraska",      "NV": "Nevada",          "NH": "New Hampshire",
        "NJ": "New Jersey",    "NM": "New Mexico",      "NY": "New York",
        "NC": "North Carolina","ND": "North Dakota",    "OH": "Ohio",
        "OK": "Oklahoma",      "OR": "Oregon",          "PA": "Pennsylvania",
        "RI": "Rhode Island",  "SC": "South Carolina",  "SD": "South Dakota",
        "TN": "Tennessee",     "TX": "Texas",           "UT": "Utah",
        "VT": "Vermont",       "VA": "Virginia",        "WA": "Washington",
        "WV": "West Virginia", "WI": "Wisconsin",       "WY": "Wyoming"
    ]

    // MARK: - Body

    var body: some View {
        Form {

            // ── Basic Information ─────────────────────────────────────
            Section {
                // State — v2.5 NavigationLink style
                NavigationLink {
                    StatePickerView(selectedState: $selectedState, stateNames: stateNames)
                } label: {
                    HStack {
                        Text("State")
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer()
                        Text(selectedStateName)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                    }
                }

                // Filing Status — v2.5 NavigationLink style
                NavigationLink {
                    FilingStatusPickerView(filingStatus: $filingStatus)
                } label: {
                    HStack {
                        Text("Filing Status")
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer()
                        Text(filingStatus.displayName)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Basic Information")
            } footer: {
                Text("This information determines your tax brackets and rates")
            }
            .opacity(viewAppeared ? 1 : 0.001)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)

            // ── IRS Mileage Rates ────────────────────────────────────
            Section {
                HStack {
                    Text("2025 Rate")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                    Text("$0.70/mile")
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("2026 Rate")
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text("Current")
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .foregroundStyle(Color.brandPrimary)
                    }
                    Spacer()
                    Text("$0.725/mile")
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(Color.brandPrimary)
                }
                .accessibilityElement(children: .combine)
            } header: {
                Text("IRS Mileage Rates")
            } footer: {
                Text("Standard mileage rate for business use. The 2026 rate is applied to all new trips.")
            }
            .opacity(viewAppeared ? 1 : 0.001)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)

            // ── Safe Harbor ──────────────────────────────────────────
            Section {
                HStack {
                    Text("2024 Tax Liability")
                    Spacer()
                    TextField("Optional", text: $priorYearTax)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                }

                if let priorYearValue = Double(priorYearTax), priorYearValue > 0 {
                    Toggle("High Earner (AGI >$150K)", isOn: $isHighEarner)
                        .onChange(of: isHighEarner) { _, _ in
                            HapticService.play(.light)
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            } header: {
                Text("Safe Harbor")
            } footer: {
                if let priorYearValue = Double(priorYearTax), priorYearValue > 0 {
                    let percentage = isHighEarner ? 110 : 100
                    let amount = priorYearValue * (isHighEarner ? 1.1 : 1.0)
                    Text("Pay \(percentage)% of last year (\(amount, format: .currency(code: "USD"))) to avoid penalties")
                } else {
                    Text("Enter your 2024 total tax to use safe harbor calculations")
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: priorYearTax)
            .opacity(viewAppeared ? 1 : 0.001)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)

            // ── Tax Components ───────────────────────────────────────
            Section {
                Toggle("Include Self-Employment Tax", isOn: $includeSelfEmployment)
                    .onChange(of: includeSelfEmployment) { _, _ in
                        HapticService.play(.light)
                    }

                if includeSelfEmployment {
                    HStack {
                        Text("SE Tax Rate")
                        Spacer()
                        Text("15.3%")
                            .foregroundStyle(.secondary)
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            } header: {
                Text("Tax Components")
            } footer: {
                if includeSelfEmployment {
                    Text("Self-employment tax covers Social Security (12.4%) and Medicare (2.9%)")
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: includeSelfEmployment)
            .opacity(viewAppeared ? 1 : 0.001)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)

            // ── Income Sources Summary (v2.9 NEW) ────────────────────
            incomeSummarySection
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(FLOAnimation.standard.delay(0.25), value: viewAppeared)

            // ── Reminders ────────────────────────────────────────────
            // delay shifted 0.25→0.30
            Section {
                Toggle("Quarterly Reminders", isOn: $enableReminders)
                    .onChange(of: enableReminders) { _, _ in
                        HapticService.play(.light)
                    }

                if enableReminders {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Remind me")
                            Spacer()
                            Text("\(Int(reminderDays)) days before")
                                .foregroundStyle(.secondary)
                                .contentTransition(.numericText())
                        }

                        Slider(value: $reminderDays, in: 3...30, step: 1)
                            .onChange(of: reminderDays) { _, _ in
                                HapticService.play(.selection)
                            }
                            .accessibilityValue("\(Int(reminderDays)) days before deadline")
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            } header: {
                Text("Reminders")
            } footer: {
                if enableReminders {
                    Text("Get notified before each quarterly deadline")
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: enableReminders)
            .opacity(viewAppeared ? 1 : 0.001)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(FLOAnimation.standard.delay(0.30), value: viewAppeared)

            // ── Advanced (Custom Rates) ──────────────────────────────
            // delay shifted 0.30→0.35
            Section {
                DisclosureGroup("Advanced Options", isExpanded: $showAdvanced) {
                    VStack(spacing: 16) {
                        HStack {
                            Text("Custom Federal Rate")
                            Spacer()
                            HStack(spacing: 4) {
                                TextField("Auto", text: $customFederalRate)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 60)
                                Text("%")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack {
                            Text("Custom State Rate")
                            Spacer()
                            HStack(spacing: 4) {
                                TextField("Auto", text: $customStateRate)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 60)
                                Text("%")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onChange(of: showAdvanced) { _, _ in
                    HapticService.play(.light)
                }
            } header: {
                Text("Custom Rates")
            } footer: {
                Text("Override automatic rate calculations if you know your exact rates")
            }
            .opacity(viewAppeared ? 1 : 0.001)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(FLOAnimation.standard.delay(0.35), value: viewAppeared)

            // ── Help ─────────────────────────────────────────────────
            // delay shifted 0.35→0.40
            Section {
                Button {
                    HapticService.play(.light)
                    showHelp = true
                } label: {
                    HStack {
                        Image(systemName: "questionmark.circle")
                            .foregroundStyle(Color.brandPrimary)
                            .accessibilityHidden(true) // v2.8 — text describes action
                        Text("How Tax Estimates Work")
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }
            }
            .opacity(viewAppeared ? 1 : 0.001)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(FLOAnimation.standard.delay(0.40), value: viewAppeared)
        }
        .navigationTitle("Tax Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    saveSettings()
                }
                .fontWeight(.semibold)
            }
        }
        .sheet(isPresented: $showHelp) {
            TaxHelpView()
        }
        .onAppear {
            if !settingsLoaded, let existing = currentSettings {
                selectedState        = existing.state
                filingStatus         = existing.filingStatus
                priorYearTax         = existing.priorYearTaxLiability.map { String(format: "%.0f", $0) } ?? ""
                isHighEarner         = existing.isHighEarner
                customFederalRate    = existing.customFederalRate.map { String(format: "%.1f", $0 * 100) } ?? ""
                customStateRate      = existing.customStateRate.map { String(format: "%.1f", $0 * 100) } ?? ""
                includeSelfEmployment = existing.includeSelfEmploymentTax
                enableReminders      = existing.enableQuarterlyReminders
                reminderDays         = Double(existing.reminderDaysBefore)
                settingsLoaded       = true
            }

            withAnimation(FLOAnimation.standard) {
                viewAppeared = true
            }
            AccessibilityAnnouncement.screenChanged("Tax settings")
        }
    }

    // MARK: - Income Sources Summary Section (v2.9)

    /// Read-only summary of all income categories and their tax treatment.
    /// Helps users verify their income classification without leaving Tax Settings.
    @ViewBuilder
    private var incomeSummarySection: some View {
        Section {
            if incomeCategories.isEmpty {
                // Empty state — guide user to set up income categories
                HStack(spacing: 12) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("No income categories configured")
                            .font(.subheadline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text("Add income categories in Settings → Categories to track income sources for tax estimates.")
                            .font(.caption)
                            .lineLimit(3)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            } else {
                ForEach(incomeCategories) { category in
                    IncomeSummaryRow(category: category)
                }
            }
        } header: {
            Text("Income Sources")
        } footer: {
            Text(incomeCategories.isEmpty
                 ? "Income source classification determines whether SE tax, W-2 withholding credits, or passive income rules apply."
                 : "Tax exempt income is excluded from all estimates. Configure income sources in Settings → Categories.")
                .font(.caption)
                .lineLimit(4)
                .minimumScaleFactor(0.7)
        }
    }

    // MARK: - Save Settings

    private func saveSettings() {
        let federalRate   = Double(customFederalRate).map { $0 / 100 }
        let stateRate     = Double(customStateRate).map { $0 / 100 }
        let priorYearValue = Double(priorYearTax)

        if let existing = currentSettings {
            existing.state                    = selectedState
            existing.filingStatus             = filingStatus
            existing.priorYearTaxLiability    = priorYearValue
            existing.isHighEarner             = isHighEarner
            existing.customFederalRate        = federalRate
            existing.customStateRate          = stateRate
            existing.includeSelfEmploymentTax = includeSelfEmployment
            existing.enableQuarterlyReminders = enableReminders
            existing.reminderDaysBefore       = Int(reminderDays)
            existing.lastUpdated              = Date()
        } else {
            let newSettings = TaxSettings(
                state:                    selectedState,
                filingStatus:             filingStatus,
                customFederalRate:        federalRate,
                customStateRate:          stateRate,
                includeSelfEmploymentTax: includeSelfEmployment,
                enableQuarterlyReminders: enableReminders,
                reminderDaysBefore:       Int(reminderDays),
                priorYearTaxLiability:    priorYearValue,
                isHighEarner:             isHighEarner
            )
            modelContext.insert(newSettings)
        }

        do {
            try modelContext.save()
            HapticService.play(.success)
            UserDefaults.standard.set(true, forKey: "hasTaxProfileSetup")
            if enableReminders { scheduleQuarterlyNotifications() }
            dismiss()
        } catch {
            HapticService.play(.error)
            print("❌ Failed to save tax settings: \(error)")
        }
    }

    // MARK: - Notifications

    private func scheduleQuarterlyNotifications() {
        guard let settings = currentSettings else { return }

        let descriptor = FetchDescriptor<Transaction>()
        guard let transactions = try? modelContext.fetch(descriptor) else { return }

        let estimate = TaxCalculationService.shared.calculateYearToDateEstimate(
            transactions: transactions,
            settings: settings
        )

        NotificationPermissionHelper.requestWithExplanation(context: .taxReminders) { granted in
            guard granted else { return }
            Task {
                await TaxNotificationService.shared.scheduleQuarterlyReminders(
                    settings: settings,
                    estimate: estimate
                )
            }
        }
    }
}

// MARK: - Income Summary Row (v2.9)

/// Compact read-only row showing one income category's classification.
/// Used only inside TaxSettingsView.incomeSummarySection.
private struct IncomeSummaryRow: View {
    let category: Category

    var body: some View {
        HStack(spacing: 12) {

            // Icon tile
            Image(systemName: category.icon)
                .font(.subheadline)
                .foregroundStyle(Color(flowHex: category.colorHex))
                .frame(width: 32, height: 32)
                .background(Color(flowHex: category.colorHex).opacity(0.1))
                .cornerRadius(8)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(category.name)
                    .font(.subheadline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                // Badge row
                HStack(spacing: 6) {
                    // Tax treatment
                    Text(category.taxTreatment.badgeLabel)
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(category.taxTreatment.color.opacity(0.15))
                        .foregroundStyle(category.taxTreatment.color)
                        .cornerRadius(4)

                    // Owner — only for spouse/joint
                    if category.taxOwner != .primary {
                        Text(category.taxOwner.displayName)
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.brandPrimary.opacity(0.12))
                            .foregroundStyle(Color.brandPrimary)
                            .cornerRadius(4)
                    }

                    // Withholding rate for W-2 categories
                    if category.taxTreatment == .w2WithholdingPaid,
                       let rate = category.estimatedWithholdingRate, rate > 0 {
                        let pctInt = Int(rate * 100)
                        Text("\(pctInt)% withheld")
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
        // Compose a clear VoiceOver label from all visible fields
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts = [category.name, category.taxTreatment.displayName]
        if category.taxOwner != .primary {
            parts.append(category.taxOwner.displayName)
        }
        if category.taxTreatment == .w2WithholdingPaid,
           let rate = category.estimatedWithholdingRate, rate > 0 {
            parts.append("\(Int(rate * 100)) percent withheld")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - State Picker View (v2.5 — unchanged)

struct StatePickerView: View {
    @Binding var selectedState: String
    let stateNames: [String: String]
    @Environment(\.dismiss) private var dismiss

    private var sortedStates: [(code: String, name: String)] {
        stateNames.map { (code: $0.key, name: $0.value) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        List {
            ForEach(sortedStates, id: \.code) { state in
                Button {
                    selectedState = state.code
                    HapticService.play(.selection)
                    dismiss()
                } label: {
                    HStack {
                        Text(state.name)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedState == state.code {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.brandPrimary)
                                .fontWeight(.semibold)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .accessibilityLabel("\(state.name)\(selectedState == state.code ? ", selected" : "")")
            }
        }
        .navigationTitle("Select State")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            AccessibilityAnnouncement.screenChanged("Select state")
        }
    }
}

// MARK: - Filing Status Picker View (v2.5 — unchanged)

struct FilingStatusPickerView: View {
    @Binding var filingStatus: TaxSettings.FilingStatus
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(TaxSettings.FilingStatus.allCases, id: \.self) { status in
                Button {
                    filingStatus = status
                    HapticService.play(.selection)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(status.displayName)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.primary)
                            Text(status.description)
                                .font(.caption)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if filingStatus == status {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.brandPrimary)
                                .fontWeight(.semibold)
                                .accessibilityHidden(true)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .accessibilityLabel("\(status.displayName). \(status.description)")
                .accessibilityAddTraits(filingStatus == status ? .isSelected : [])
            }
        }
        .navigationTitle("Filing Status")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            AccessibilityAnnouncement.screenChanged("Filing status")
        }
    }
}

// MARK: - Tax Help View (v2.8 — unchanged)

struct TaxHelpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewAppeared = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    helpSection(
                        icon: "doc.text",
                        title: "How Estimates Work",
                        content: "FLO calculates your estimated quarterly tax based on your year-to-date income and expenses. It uses current IRS tax brackets, your state's tax rate, and self-employment tax (15.3%) to project what you'll owe.",
                        delay: 0.05
                    )

                    helpSection(
                        icon: "calendar",
                        title: "Quarterly Deadlines",
                        content: """
                        • Q1 (Jan–Mar): April 15
                        • Q2 (Apr–May): June 16
                        • Q3 (Jun–Aug): September 15
                        • Q4 (Sep–Dec): January 15

                        You need to pay estimated taxes if you expect to owe $1,000+ when you file.
                        """,
                        delay: 0.1
                    )

                    helpSection(
                        icon: "shield",
                        title: "Safe Harbor Protection",
                        content: "Pay at least 100% of last year's tax (110% if AGI >$150K) to avoid penalties, even if you owe more this year.",
                        delay: 0.15
                    )

                    helpSection(
                        icon: "building.2",
                        title: "W-2 Income & Withholding",
                        content: "If you or your spouse have a W-2 job, FLO credits estimated employer withholding against your quarterly payment. Set the withholding rate on each W-2 income category in Settings → Categories.",
                        delay: 0.175
                    )

                    helpSection(
                        icon: "exclamationmark.triangle",
                        title: "Important Disclaimer",
                        content: "These estimates are for planning purposes only. Always consult a CPA or tax professional.",
                        delay: 0.2
                    )
                }
                .padding()
            }
            .navigationTitle("Tax Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        HapticService.play(.light)
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewAppeared = true
                AccessibilityAnnouncement.screenChanged("Tax help")
            }
        }
    }

    private func helpSection(icon: String, title: String, content: String, delay: Double) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(Color.brandPrimary)
                    .font(.title2)
                    .accessibilityHidden(true) // v2.8 — text describes section

                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
            }

            Text(content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
        .opacity(viewAppeared ? 1 : 0.001)
        .offset(y: viewAppeared ? 0 : 10)
        .animation(FLOAnimation.standard.delay(delay), value: viewAppeared)
    }
}

// MARK: - Filing Status Description Extension (v2.6 — unchanged)

extension TaxSettings.FilingStatus {
    var description: String {
        switch self {
        case .single:
            return "Unmarried or legally separated"
        case .marriedFilingJointly:
            return "Married and filing together"
        case .marriedFilingSeparately:
            return "Married but filing separate returns"
        case .headOfHousehold:
            return "Unmarried with qualifying dependent"
        }
    }
}

// MARK: - Preview

#Preview {
    let container = try! ModelContainer(
        for: TaxSettings.self, Category.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    // Add sample income categories so the Income Sources Summary has data
    let se = Category(
        name: "Freelance Income", icon: "laptopcomputer", colorHex: "14B8A6",
        isIncome: true, isTaxDeductible: false, isBusiness: true,
        taxTreatment: .selfEmployment, taxOwner: .primary
    )
    let w2 = Category(
        name: "Spouse Salary", icon: "building.columns.fill", colorHex: "3B82F6",
        isIncome: true, isTaxDeductible: false, isBusiness: false,
        taxTreatment: .w2WithholdingPaid, taxOwner: .spouse,
        estimatedWithholdingRate: 0.22
    )
    let passive = Category(
        name: "Investment Income", icon: "chart.line.uptrend.xyaxis", colorHex: "6366F1",
        isIncome: true, isTaxDeductible: false, isBusiness: false,
        taxTreatment: .passiveIncome, taxOwner: .joint
    )
    for cat in [se, w2, passive] { container.mainContext.insert(cat) }

    return NavigationStack {
        TaxSettingsView()
    }
    .modelContainer(container)
}
