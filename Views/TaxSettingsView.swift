//  TaxSettingsView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.6 - Accessibility audit (Sprint 6c)
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v2.6:
//  ✅ Full VoiceOver accessibility coverage
//  ✅ Screen change announcements on main and help views
//  ✅ IRS mileage rate rows combined with spoken values
//  ✅ Help chevron hidden, help section titles get .isHeader trait
//  ✅ Reminder slider has accessibility value
//  ✅ Picker rows combined with spoken selected values
//  ✅ Fixed garbled UTF-8 characters
//
//  CHANGES v2.5:
//  ✅ FIXED: State picker now shows selected value correctly
//  ✅ FIXED: Filing status picker now shows selected value correctly
//  ✅ Changed to NavigationLink picker style for reliable display
//  ✅ Added state name lookup for clearer display
//
//  CHANGES v2.4:
//  ✅ FIXED: Removed init() that created separate ModelContainer
//  ✅ Now uses @Query + onAppear to load existing settings
//  ✅ Eliminates CloudKit errors from rogue ModelContainer creation
//
//  PREVIOUS (v2.3):
//  - Haptic feedback on picker changes
//  - Haptic on toggle changes
//  - Haptic on slider changes
//  - Section entrance animations
//  - Save/Cancel button haptics
//  - Advanced section expand animation
//

import SwiftUI
import SwiftData

struct TaxSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var taxSettings: [TaxSettings]
    
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
    
    private var currentSettings: TaxSettings? {
        taxSettings.first
    }
    
    // v2.5: State name lookup for display
    private var selectedStateName: String {
        stateNames[selectedState] ?? selectedState
    }
    
    // v2.5: Full state names for display
    private let stateNames: [String: String] = [
        "AL": "Alabama", "AK": "Alaska", "AZ": "Arizona", "AR": "Arkansas",
        "CA": "California", "CO": "Colorado", "CT": "Connecticut", "DE": "Delaware",
        "DC": "Washington D.C.", "FL": "Florida", "GA": "Georgia", "HI": "Hawaii",
        "ID": "Idaho", "IL": "Illinois", "IN": "Indiana", "IA": "Iowa",
        "KS": "Kansas", "KY": "Kentucky", "LA": "Louisiana", "ME": "Maine",
        "MD": "Maryland", "MA": "Massachusetts", "MI": "Michigan", "MN": "Minnesota",
        "MS": "Mississippi", "MO": "Missouri", "MT": "Montana", "NE": "Nebraska",
        "NV": "Nevada", "NH": "New Hampshire", "NJ": "New Jersey", "NM": "New Mexico",
        "NY": "New York", "NC": "North Carolina", "ND": "North Dakota", "OH": "Ohio",
        "OK": "Oklahoma", "OR": "Oregon", "PA": "Pennsylvania", "RI": "Rhode Island",
        "SC": "South Carolina", "SD": "South Dakota", "TN": "Tennessee", "TX": "Texas",
        "UT": "Utah", "VT": "Vermont", "VA": "Virginia", "WA": "Washington",
        "WV": "West Virginia", "WI": "Wisconsin", "WY": "Wyoming"
    ]
    
    var body: some View {
        Form {
            // Basic Settings Section - v2.5: Fixed picker display
            Section {
                // State Picker - v2.5: Using NavigationLink style for reliable display
                NavigationLink {
                    StatePickerView(selectedState: $selectedState, stateNames: stateNames)
                } label: {
                    HStack {
                        Text("State")
                        Spacer()
                        Text(selectedStateName)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Filing Status Picker - v2.5: Using NavigationLink style for reliable display
                NavigationLink {
                    FilingStatusPickerView(filingStatus: $filingStatus)
                } label: {
                    HStack {
                        Text("Filing Status")
                        Spacer()
                        Text(filingStatus.displayName)
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
            
            // IRS Mileage Rates Section
            Section {
                HStack {
                    Text("2025 Rate")
                    Spacer()
                    Text("$0.70/mile")
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("2026 Rate")
                        Text("Current")
                            .font(.caption2)
                            .foregroundStyle(AppConstants.primaryColor)
                    }
                    
                    Spacer()
                    
                    Text("$0.725/mile")
                        .fontWeight(.semibold)
                        .foregroundStyle(AppConstants.primaryColor)
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
            
            // Income Information Section
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
            
            // Tax Components Section
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
            
            // Reminders Section
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
            .animation(FLOAnimation.standard.delay(0.25), value: viewAppeared)
            
            // Advanced Section
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
            .animation(FLOAnimation.standard.delay(0.3), value: viewAppeared)
            
            // Help Section
            Section {
                Button {
                    HapticService.play(.light)
                    showHelp = true
                } label: {
                    HStack {
                        Image(systemName: "questionmark.circle")
                            .foregroundStyle(AppConstants.primaryColor)
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
            .animation(FLOAnimation.standard.delay(0.35), value: viewAppeared)
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
            // Load existing settings from @Query results
            if !settingsLoaded, let existing = currentSettings {
                selectedState = existing.state
                filingStatus = existing.filingStatus
                priorYearTax = existing.priorYearTaxLiability.map { String(format: "%.0f", $0) } ?? ""
                isHighEarner = existing.isHighEarner
                customFederalRate = existing.customFederalRate.map { String(format: "%.1f", $0 * 100) } ?? ""
                customStateRate = existing.customStateRate.map { String(format: "%.1f", $0 * 100) } ?? ""
                includeSelfEmployment = existing.includeSelfEmploymentTax
                enableReminders = existing.enableQuarterlyReminders
                reminderDays = Double(existing.reminderDaysBefore)
                settingsLoaded = true
            }
            
            withAnimation(FLOAnimation.standard) {
                viewAppeared = true
            }
            AccessibilityAnnouncement.screenChanged("Tax settings")
        }
    }
    
    // MARK: - Save Settings
    
    private func saveSettings() {
        let federalRate = Double(customFederalRate).map { $0 / 100 }
        let stateRate = Double(customStateRate).map { $0 / 100 }
        let priorYearValue = Double(priorYearTax)
        
        if let existing = currentSettings {
            existing.state = selectedState
            existing.filingStatus = filingStatus
            existing.priorYearTaxLiability = priorYearValue
            existing.isHighEarner = isHighEarner
            existing.customFederalRate = federalRate
            existing.customStateRate = stateRate
            existing.includeSelfEmploymentTax = includeSelfEmployment
            existing.enableQuarterlyReminders = enableReminders
            existing.reminderDaysBefore = Int(reminderDays)
            existing.lastUpdated = Date()
        } else {
            let newSettings = TaxSettings(
                state: selectedState,
                filingStatus: filingStatus,
                customFederalRate: federalRate,
                customStateRate: stateRate,
                includeSelfEmploymentTax: includeSelfEmployment,
                enableQuarterlyReminders: enableReminders,
                reminderDaysBefore: Int(reminderDays),
                priorYearTaxLiability: priorYearValue,
                isHighEarner: isHighEarner
            )
            modelContext.insert(newSettings)
        }
        
        do {
            try modelContext.save()
            HapticService.play(.success)
            
            // Mark tax profile as set up for Getting Started card
            UserDefaults.standard.set(true, forKey: "hasTaxProfileSetup")
            
            if enableReminders {
                scheduleQuarterlyNotifications()
            }
            
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

// MARK: - State Picker View (v2.5)

struct StatePickerView: View {
    @Binding var selectedState: String
    let stateNames: [String: String]
    @Environment(\.dismiss) private var dismiss
    
    // Sorted states for display
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
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedState == state.code {
                            Image(systemName: "checkmark")
                                .foregroundStyle(AppConstants.primaryColor)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
        .navigationTitle("Select State")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Filing Status Picker View (v2.5)

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
                                .foregroundStyle(.primary)
                            Text(status.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if filingStatus == status {
                            Image(systemName: "checkmark")
                                .foregroundStyle(AppConstants.primaryColor)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Filing Status")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Tax Help View

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
                        • Q1 (Jan-Mar): April 15
                        • Q2 (Apr-May): June 16
                        • Q3 (Jun-Aug): September 15
                        • Q4 (Sep-Dec): January 15
                        
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
                    .foregroundStyle(AppConstants.primaryColor)
                    .font(.title2)
                
                Text(title)
                    .font(.headline)
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

// MARK: - Filing Status Description Extension

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
    NavigationStack {
        TaxSettingsView()
    }
    .modelContainer(for: TaxSettings.self, inMemory: true)
}
