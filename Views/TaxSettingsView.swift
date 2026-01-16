//  TaxSettingsView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.3 - Enhanced haptics and micro-animations
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v2.3:
//  ✅ Haptic feedback on picker changes
//  ✅ Haptic on toggle changes
//  ✅ Haptic on slider changes
//  ✅ Section entrance animations
//  ✅ Save/Cancel button haptics
//  ✅ Advanced section expand animation
//
//  PREVIOUS (v2.2):
//  - Notification permission explanations

import SwiftUI
import SwiftData

struct TaxSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var taxSettings: [TaxSettings]
    
    @State private var selectedState: String
    @State private var filingStatus: TaxSettings.FilingStatus
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
    
    // Haptic Generators
                    
    private var currentSettings: TaxSettings? {
        taxSettings.first
    }
    
    init() {
        if let existing = try? ModelContext(ModelContainer(for: TaxSettings.self)).fetch(FetchDescriptor<TaxSettings>()).first {
            _selectedState = State(initialValue: existing.state)
            _filingStatus = State(initialValue: existing.filingStatus)
            _priorYearTax = State(initialValue: existing.priorYearTaxLiability.map { String(format: "%.0f", $0) } ?? "")
            _isHighEarner = State(initialValue: existing.isHighEarner)
            _customFederalRate = State(initialValue: existing.customFederalRate.map { String(format: "%.1f", $0 * 100) } ?? "")
            _customStateRate = State(initialValue: existing.customStateRate.map { String(format: "%.1f", $0 * 100) } ?? "")
            _includeSelfEmployment = State(initialValue: existing.includeSelfEmploymentTax)
            _enableReminders = State(initialValue: existing.enableQuarterlyReminders)
            _reminderDays = State(initialValue: Double(existing.reminderDaysBefore))
        } else {
            _selectedState = State(initialValue: "CA")
            _filingStatus = State(initialValue: .single)
        }
    }
    
    var body: some View {
        Form {
            // Basic Settings Section
            Section {
                Picker("State", selection: $selectedState) {
                    ForEach(Array(TaxSettings.stateTaxRates.keys.sorted()), id: \.self) { state in
                        Text(state).tag(state)
                    }
                }
                .onChange(of: selectedState) { _, _ in
                    HapticService.play(.selection)
                }
                
                Picker("Filing Status", selection: $filingStatus) {
                    ForEach(TaxSettings.FilingStatus.allCases, id: \.self) { status in
                        Text(status.displayName).tag(status)
                    }
                }
                .onChange(of: filingStatus) { _, _ in
                    HapticService.play(.selection)
                }
            } header: {
                Text("Basic Information")
            } footer: {
                Text("This information determines your tax brackets and rates")
            }
            .opacity(viewAppeared ? 1 : 0)
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
            } header: {
                Text("IRS Mileage Rates")
            } footer: {
                Text("Standard mileage rate for business use. The 2026 rate is applied to all new trips.")
            }
            .opacity(viewAppeared ? 1 : 0)
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
            .opacity(viewAppeared ? 1 : 0)
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
            .opacity(viewAppeared ? 1 : 0)
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
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            } header: {
                Text("Notifications")
            } footer: {
                if enableReminders {
                    Text("Reminders for quarterly deadlines: Apr 15, Jun 16, Sep 15, Jan 15")
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: enableReminders)
            .opacity(viewAppeared ? 1 : 0)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(FLOAnimation.standard.delay(0.25), value: viewAppeared)
            
            // Advanced Settings
            Section {
                Button {
                    HapticService.play(.light)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showAdvanced.toggle()
                    }
                } label: {
                    HStack {
                        Text("Advanced Settings")
                        Spacer()
                        Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                            .foregroundStyle(.secondary)
                    }
                }
                
                if showAdvanced {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Custom Federal Rate")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            HStack {
                                TextField("Auto-calculated", text: $customFederalRate)
                                    .keyboardType(.decimalPad)
                                Text("%")
                                    .foregroundStyle(.secondary)
                            }
                            
                            Text("Leave blank to use automatic progressive brackets")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Custom State Rate")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            HStack {
                                TextField("Auto-calculated", text: $customStateRate)
                                    .keyboardType(.decimalPad)
                                Text("%")
                                    .foregroundStyle(.secondary)
                            }
                            
                            if let defaultRate = TaxSettings.stateTaxRates[selectedState] {
                                Text("Default \(selectedState) rate: \(defaultRate * 100, specifier: "%.1f")%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            } header: {
                Text("Override Calculations")
            } footer: {
                Text("Only change these if you know your specific tax rates")
            }
            .opacity(viewAppeared ? 1 : 0)
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
                        Text("How Tax Estimates Work")
                    }
                }
            }
            .opacity(viewAppeared ? 1 : 0)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(FLOAnimation.standard.delay(0.35), value: viewAppeared)
            
            // Save/Cancel Buttons
            Section {
                Button {
                    HapticService.play(.medium)
                    saveSettings()
                } label: {
                    Text("Save Settings")
                        .frame(maxWidth: .infinity)
                        .fontWeight(.semibold)
                }
                
                Button(role: .cancel) {
                    HapticService.play(.light)
                    dismiss()
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                }
            }
            .opacity(viewAppeared ? 1 : 0)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(FLOAnimation.standard.delay(0.4), value: viewAppeared)
        }
        .navigationTitle("Tax Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showHelp) {
            TaxHelpView()
        }
        .onAppear {
                        withAnimation(FLOAnimation.standard) {
                viewAppeared = true
            }
        }
    }
    
    // MARK: - Haptic Preparation
    
        
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
                }
                
                Text(content)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
            .opacity(viewAppeared ? 1 : 0)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(FLOAnimation.standard.delay(delay), value: viewAppeared)
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
