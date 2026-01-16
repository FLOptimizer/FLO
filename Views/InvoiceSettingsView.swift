//  InvoiceSettingsView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.2 - Enhanced haptics and micro-animations
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.2:
//  ✅ Haptic feedback on picker changes
//  ✅ Haptic on toggle changes
//  ✅ Haptic on stepper changes
//  ✅ Section entrance animations
//  ✅ Warning icon pulse animation
//
//  PREVIOUS (v1.1):
//  - Notification permission request on toggle

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
    
    // Haptic Generators
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    
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
                .listRowBackground(defaultPaymentTerms == 30 ? Color(.secondarySystemBackground) : nil)
                .onChange(of: defaultPaymentTerms) { _, _ in
                    selectionFeedback.selectionChanged()
                }
                
                Picker("Currency", selection: $defaultCurrency) {
                    Text("USD ($)").tag("USD")
                    Text("EUR (€)").tag("EUR")
                    Text("GBP (£)").tag("GBP")
                    Text("CAD (C$)").tag("CAD")
                }
                .onChange(of: defaultCurrency) { _, _ in
                    selectionFeedback.selectionChanged()
                }
            } header: {
                Text("Invoice Defaults")
            }
            .opacity(viewAppeared ? 1 : 0)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: viewAppeared)
            
            Section {
                Toggle("Enable Payment Reminders", isOn: Binding(
                    get: { enableReminders },
                    set: { newValue in
                        if newValue {
                            impactMedium.impactOccurred()
                            requestNotificationPermission()
                        } else {
                            impactLight.impactOccurred()
                            enableReminders = false
                        }
                    }
                ))
                
                if enableReminders {
                    if !notificationsAuthorized {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .symbolEffect(.pulse, value: viewAppeared)
                            Text("Notifications disabled in Settings")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Fix") {
                                impactMedium.impactOccurred()
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
                            selectionFeedback.selectionChanged()
                        }
                    
                    Stepper("Follow up \(reminderDaysAfterDue) days after due", value: $reminderDaysAfterDue, in: 1...30)
                        .onChange(of: reminderDaysAfterDue) { _, _ in
                            selectionFeedback.selectionChanged()
                        }
                }
            } header: {
                Text("Payment Reminders")
            } footer: {
                Text("Automatically notify you to send payment reminders to clients")
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: enableReminders)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: notificationsAuthorized)
            .opacity(viewAppeared ? 1 : 0)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: viewAppeared)
            
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
            .opacity(viewAppeared ? 1 : 0)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: viewAppeared)
        }
        .navigationTitle("Invoice Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            prepareHaptics()
            checkNotificationStatus()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                viewAppeared = true
            }
        }
        .alert("Notifications Required", isPresented: $showingNotificationDeniedAlert) {
            Button("Open Settings") {
                impactMedium.impactOccurred()
                openNotificationSettings()
            }
            Button("Cancel", role: .cancel) {
                impactLight.impactOccurred()
                enableReminders = false
            }
        } message: {
            Text("Payment reminders require notification permissions. Please enable notifications in Settings.")
        }
    }
    
    // MARK: - Haptic Preparation
    
    private func prepareHaptics() {
        selectionFeedback.prepare()
        impactLight.prepare()
        impactMedium.prepare()
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
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
}

struct InvoiceTemplateEditor: View {
    @State private var viewAppeared = false
    
    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 40))
                        .foregroundStyle(AppConstants.primaryColor)
                        .symbolEffect(.bounce, value: viewAppeared)
                    
                    Text("Invoice template customization coming soon")
                        .foregroundStyle(.secondary)
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

struct BusinessInfoEditor: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("businessName") private var businessName = ""
    @AppStorage("businessAddress") private var businessAddress = ""
    @AppStorage("businessPhone") private var businessPhone = ""
    @AppStorage("businessEmail") private var businessEmail = ""
    @AppStorage("businessWebsite") private var businessWebsite = ""
    
    @State private var viewAppeared = false
    
    // Haptic Generators
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
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
            .opacity(viewAppeared ? 1 : 0)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: viewAppeared)
        }
        .navigationTitle("Business Info")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    impactLight.impactOccurred()
                    notificationFeedback.notificationOccurred(.success)
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                viewAppeared = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        InvoiceSettingsView()
    }
}
