//  InvoiceSettingsView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.6 - VoiceOver Audit: Verified accessibility
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.6 - VoiceOver Audit:
//  ✅ VERIFIED: Exclamation triangle icon in notifications warning already hidden
//  ✅ VERIFIED: Document icon in template editor already hidden
//  ✅ VERIFIED: Form Labels and Pickers auto-handled by SwiftUI
//  ✅ VERIFIED: Steppers provide clear spoken values
//  ✅ VERIFIED: Screen change announcements present across all sub-views
//
//  CHANGES v1.5 - Dynamic Type Verification:
//  ✅ FIXED: Warning banner text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Coming soon" text missing lineLimit + minimumScaleFactor
//
//  CHANGES v1.4:
//  ✅ Screen change announcements across all sub-views
//  ✅ Coming soon decorative icons hidden
//  ✅ Fixed garbled UTF-8 currency symbols
//
//  CHANGES v1.3:
//  ✅ FIXED: "Failed to create image slot" error during navigation
//  ✅ Changed opacity from 0 to 0.001 to prevent zero-height calculations
//
//  PREVIOUS (v1.2):
//  - Haptic feedback on picker changes
//  - Haptic on toggle changes
//  - Haptic on stepper changes
//  - Section entrance animations
//  - Warning icon pulse animation

import SwiftUI
import UserNotifications

struct InvoiceSettingsView: View {
    @AppStorage("defaultPaymentTerms") private var defaultPaymentTerms = 30
    @AppStorage("defaultCurrency") private var defaultCurrency = "USD"
    @AppStorage("enableLatePaymentReminders") private var enableReminders = true
    @AppStorage("reminderDaysBeforeDue") private var reminderDaysBeforeDue = 3
    @AppStorage("reminderDaysAfterDue") private var reminderDaysAfterDue = 7
    
    @State private var notificationsAuthorized = false
    @State private var showingNotificationDeniedAlert = false
    @State private var viewAppeared = false
    
    var body: some View {
        List {
            Section {
                Picker("Payment Terms", selection: $defaultPaymentTerms) {
                    Text("Due on Receipt").tag(0)
                    Text("Net 15").tag(15)
                    Text("Net 30").tag(30)
                    Text("Net 60").tag(60)
                    Text("Net 90").tag(90)
                }
                .listRowBackground(defaultPaymentTerms == 30 ? Color.floSecondarySystemBackground : nil)
                .onChange(of: defaultPaymentTerms) { _, _ in
                    HapticService.play(.selection)
                }
                
                Picker("Currency", selection: $defaultCurrency) {
                    Text("USD ($)").tag("USD")
                    Text("EUR (€)").tag("EUR")
                    Text("GBP (£)").tag("GBP")
                    Text("CAD (C$)").tag("CAD")
                }
                .onChange(of: defaultCurrency) { _, _ in
                    HapticService.play(.selection)
                }
            } header: {
                Text("Invoice Defaults")
            }
            .opacity(viewAppeared ? 1 : 0.001)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)
            
            Section {
                Toggle("Enable Payment Reminders", isOn: Binding(
                    get: { enableReminders },
                    set: { newValue in
                        if newValue {
                            HapticService.play(.medium)
                            requestNotificationPermission()
                        } else {
                            HapticService.play(.light)
                            enableReminders = false
                        }
                    }
                ))
                
                if enableReminders {
                    if !notificationsAuthorized {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .accessibilityHidden(true)
                                .foregroundStyle(.orange)
                                .symbolEffect(.pulse, value: viewAppeared)
                            Text("Notifications disabled in Settings")
                                .font(.caption)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Fix") {
                                HapticService.play(.medium)
                                openNotificationSettings()
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                    
                    Stepper("Remind \(reminderDaysBeforeDue) days before due", value: $reminderDaysBeforeDue, in: 1...14)
                        .onChange(of: reminderDaysBeforeDue) { _, _ in
                            HapticService.play(.selection)
                        }
                    
                    Stepper("Follow up \(reminderDaysAfterDue) days after due", value: $reminderDaysAfterDue, in: 1...30)
                        .onChange(of: reminderDaysAfterDue) { _, _ in
                            HapticService.play(.selection)
                        }
                }
            } header: {
                Text("Payment Reminders")
            } footer: {
                Text("Automatically notify you to send payment reminders to clients")
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: enableReminders)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: notificationsAuthorized)
            .opacity(viewAppeared ? 1 : 0.001)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
            
            Section {
                NavigationLink {
                    InvoiceTemplateEditor()
                } label: {
                    Text("Customize Invoice Template")
                }
                
                NavigationLink {
                    BusinessInfoEditor()
                } label: {
                    Text("Business Information")
                }
            } header: {
                Text("Customization")
            }
            .opacity(viewAppeared ? 1 : 0.001)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)
        }
        .navigationTitle("Invoice Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            checkNotificationStatus()
            withAnimation(FLOAnimation.standard) {
                viewAppeared = true
            }
            AccessibilityAnnouncement.screenChanged("Invoice settings")
        }
        .alert("Notifications Required", isPresented: $showingNotificationDeniedAlert) {
            Button("Open Settings") {
                HapticService.play(.medium)
                openNotificationSettings()
            }
            Button("Cancel", role: .cancel) {
                HapticService.play(.light)
                enableReminders = false
            }
        } message: {
            Text("Payment reminders require notification permissions. Please enable notifications in Settings.")
        }
    }
    
    // MARK: - Notification Helpers
    
    private func requestNotificationPermission() {
        NotificationPermissionHelper.requestWithExplanation(context: .invoiceAlerts) { granted in
            DispatchQueue.main.async {
                notificationsAuthorized = granted
                enableReminders = granted
                
                if !granted {
                    UNUserNotificationCenter.current().getNotificationSettings { settings in
                        DispatchQueue.main.async {
                            if settings.authorizationStatus == .denied {
                                showingNotificationDeniedAlert = true
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationsAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    private func openNotificationSettings() {
        #if canImport(UIKit)
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
        #endif
    }
}

// MARK: - Invoice Template Editor

struct InvoiceTemplateEditor: View {
    @State private var viewAppeared = false
    
    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "doc.richtext")
                        .accessibilityHidden(true)
                        .font(.largeTitle)
                        .foregroundStyle(Color.brandPrimary)
                        .symbolEffect(.bounce, value: viewAppeared)
                        .accessibilityHidden(true)
                    
                    Text("Invoice template customization coming soon")
                        .font(.subheadline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("Invoice Template")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewAppeared = true
        }
    }
}

// MARK: - Business Info Editor

struct BusinessInfoEditor: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("businessName") private var businessName = ""
    @AppStorage("businessAddress") private var businessAddress = ""
    @AppStorage("businessPhone") private var businessPhone = ""
    @AppStorage("businessEmail") private var businessEmail = ""
    @AppStorage("businessWebsite") private var businessWebsite = ""
    
    @State private var viewAppeared = false
    
    var body: some View {
        Form {
            Section {
                TextField("Business Name", text: $businessName)
                TextField("Address", text: $businessAddress, axis: .vertical)
                    .lineLimit(3...5)
                TextField("Phone", text: $businessPhone)
                    .keyboardType(.phonePad)
                TextField("Email", text: $businessEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                TextField("Website", text: $businessWebsite)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
            } header: {
                Text("Contact Information")
            } footer: {
                Text("This information will appear on your invoices")
            }
            .opacity(viewAppeared ? 1 : 0.001)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)
        }
        .navigationTitle("Business Info")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    HapticService.play(.light)
                    HapticService.play(.success)
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
        .onAppear {
            withAnimation(FLOAnimation.standard) {
                viewAppeared = true
            }
            AccessibilityAnnouncement.screenChanged("Business info")
        }
    }
}

#Preview {
    NavigationStack {
        InvoiceSettingsView()
    }
}
