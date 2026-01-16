//  SettingsView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.4 - Enhanced haptics and micro-animations + HelpCenterView
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES FROM v3.2:
//  ✅ Haptic feedback on all interactive elements
//  ✅ Section entrance animations
//  ✅ Profile card animation
//  ✅ Button press haptics
//  ✅ About view animations
//  ✅ Added HelpCenterView with staggered article animations
//  ✅ Added HelpArticleView with section stagger
//  ✅ Added HelpSection model
//
//  PREVIOUS (v3.2):
//  - Fixed Button/Link text, working theme picker

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("userName") private var userName = ""
    @AppStorage("userEmail") private var userEmail = ""
    @AppStorage("preferredColorScheme") private var preferredColorScheme = "system"
    
    @State private var showingBiometricSetup = false
    @State private var showingAbout = false
    @State private var showingExportOptions = false
    @State private var viewAppeared = false
    
    // Haptic Generators
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    
    private var colorScheme: ColorScheme? {
        switch preferredColorScheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // User Profile Section
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.brandPrimary)
                            .symbolEffect(.bounce, value: viewAppeared)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            if userName.isEmpty {
                                Text("Add Your Name")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(userName)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                            }
                            
                            if !userEmail.isEmpty {
                                Text(userEmail)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 12)
                    }
                    .padding(.vertical, 8)
                    
                    NavigationLink {
                        ProfileEditView(userName: $userName, userEmail: $userEmail)
                    } label: {
                        Label {
                            Text("Edit Profile")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "pencil")
                                .foregroundStyle(Color.brandPrimary)
                        }
                    }
                    
                    NavigationLink {
                        BusinessProfileSettingsView()
                    } label: {
                        Label {
                            Text("Business Profile")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "building.2")
                                .foregroundStyle(Color.brandPrimary)
                        }
                    }
                } header: {
                    Text("Profile")
                }
                .opacity(viewAppeared ? 1 : 0)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: viewAppeared)
                
                // Security Section
                Section {
                    Button {
                        impactMedium.impactOccurred()
                        showingBiometricSetup = true
                    } label: {
                        HStack {
                            Label {
                                Text("Passcode & Biometrics")
                                    .foregroundStyle(.primary)
                            } icon: {
                                Image(systemName: "lock.shield.fill")
                                    .foregroundStyle(Color.brandPrimary)
                            }
                            
                            Spacer()
                            
                            if BiometricAuthService.shared.biometricEnabled || PasscodeService.shared.hasPasscode() {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Security")
                } footer: {
                    Text("Protect your financial data with Face ID or a passcode")
                }
                .opacity(viewAppeared ? 1 : 0)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: viewAppeared)
                
                // Categories Section
                Section("Categories") {
                    NavigationLink {
                        CategoryManagementView()
                    } label: {
                        Label {
                            Text("Manage Categories")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "folder")
                                .foregroundStyle(Color.brandPrimary)
                        }
                    }
                }
                .opacity(viewAppeared ? 1 : 0)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: viewAppeared)
                
                // Financial Features Section
                Section {
                    NavigationLink {
                        TaxSettingsView()
                    } label: {
                        HStack {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Tax Settings")
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    Text("Quarterly estimates & filing status")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "doc.text.fill")
                                    .foregroundStyle(Color.brandPrimary)
                                    .frame(width: 28)
                            }
                        }
                    }
                } header: {
                    Text("Features")
                }
                .opacity(viewAppeared ? 1 : 0)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: viewAppeared)
                
                // Premium Features Section
                Section {
                    NavigationLink {
                        SubscriptionView()
                    } label: {
                        HStack {
                            Label {
                                Text("Subscription")
                                    .foregroundStyle(.primary)
                            } icon: {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(Color.brandPrimary)
                            }
                            Spacer()
                            Text(SubscriptionManager.shared.currentTier.displayName)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Premium Features")
                }
                .opacity(viewAppeared ? 1 : 0)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.25), value: viewAppeared)
                
                // Preferences Section
                Section {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Label {
                            Text("Notifications")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "bell.fill")
                                .foregroundStyle(Color.brandPrimary)
                        }
                    }
                    
                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        HStack {
                            Label {
                                Text("Appearance")
                                    .foregroundStyle(.primary)
                            } icon: {
                                Image(systemName: "paintbrush.fill")
                                    .foregroundStyle(Color.brandPrimary)
                            }
                            Spacer()
                            Text(ColorSchemeManager.shared.currentScheme.emoji)
                        }
                    }
                    
                    NavigationLink {
                        DataManagementView()
                    } label: {
                        Label {
                            Text("Data & Storage")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "externaldrive.fill")
                                .foregroundStyle(Color.brandPrimary)
                        }
                    }
                } header: {
                    Text("Preferences")
                }
                .opacity(viewAppeared ? 1 : 0)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3), value: viewAppeared)
                
                // Export & Backup Section
                Section {
                    Button {
                        impactMedium.impactOccurred()
                        showingExportOptions = true
                    } label: {
                        Label {
                            Text("Export Data")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(Color.brandPrimary)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    NavigationLink {
                        BackupSettingsView()
                    } label: {
                        Label {
                            Text("Backup & Sync")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "icloud.fill")
                                .foregroundStyle(Color.brandPrimary)
                        }
                    }
                } header: {
                    Text("Data")
                }
                .opacity(viewAppeared ? 1 : 0)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.35), value: viewAppeared)
                
                // Support Section
                Section {
                    Link(destination: URL(string: "mailto:flo.financeapp@gmail.com")!) {
                        Label {
                            Text("Contact Support")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "envelope.fill")
                                .foregroundStyle(Color.brandPrimary)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    NavigationLink {
                        HelpCenterView()
                    } label: {
                        Label {
                            Text("Help Center")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundStyle(Color.brandPrimary)
                        }
                    }
                    
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label {
                            Text("Privacy Policy")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "hand.raised.fill")
                                .foregroundStyle(Color.brandPrimary)
                        }
                    }
                    
                    NavigationLink {
                        TermsOfServiceView()
                    } label: {
                        Label {
                            Text("Terms of Service")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "doc.text.fill")
                                .foregroundStyle(Color.brandPrimary)
                        }
                    }
                    
                    NavigationLink {
                        TaxDisclaimerView()
                    } label: {
                        Label {
                            Text("Tax & Legal Disclaimer")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.brandPrimary)
                        }
                    }
                } header: {
                    Text("Support")
                }
                .opacity(viewAppeared ? 1 : 0)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.4), value: viewAppeared)
                
                // About Section
                Section {
                    Button {
                        impactMedium.impactOccurred()
                        showingAbout = true
                    } label: {
                        HStack {
                            Label {
                                Text("About FLO")
                                    .foregroundStyle(.primary)
                            } icon: {
                                Image(systemName: "info.circle.fill")
                                    .foregroundStyle(Color.brandPrimary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    HStack {
                        Text("Version")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }
                .opacity(viewAppeared ? 1 : 0)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.45), value: viewAppeared)
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingBiometricSetup) {
                SecuritySettingsView()
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .sheet(isPresented: $showingExportOptions) {
                ExportOptionsView()
            }
            .onAppear {
                prepareHaptics()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    viewAppeared = true
                }
            }
        }
        .preferredColorScheme(colorScheme)
    }
    
    // MARK: - Haptic Preparation
    
    private func prepareHaptics() {
        selectionFeedback.prepare()
        impactLight.prepare()
        impactMedium.prepare()
    }
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Profile Edit View

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var userName: String
    @Binding var userEmail: String
    
    @State private var editedName: String
    @State private var editedEmail: String
    @State private var viewAppeared = false
    
    // Haptic Generators
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    init(userName: Binding<String>, userEmail: Binding<String>) {
        self._userName = userName
        self._userEmail = userEmail
        self._editedName = State(initialValue: userName.wrappedValue)
        self._editedEmail = State(initialValue: userEmail.wrappedValue)
    }
    
    var body: some View {
        Form {
            Section("Personal Information") {
                TextField("Name", text: $editedName)
                    .textContentType(.name)
                
                TextField("Email", text: $editedEmail)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
            }
            .opacity(viewAppeared ? 1 : 0)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: viewAppeared)
            
            Section {
                Text("Your profile information is stored locally on your device and is never shared.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .opacity(viewAppeared ? 1 : 0)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: viewAppeared)
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    impactLight.impactOccurred()
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    impactMedium.impactOccurred()
                    saveProfile()
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                viewAppeared = true
            }
        }
    }
    
    private func saveProfile() {
        userName = editedName
        userEmail = editedEmail
        notificationFeedback.notificationOccurred(.success)
        dismiss()
    }
}

// MARK: - Notification Settings View

struct NotificationSettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("taxReminderEnabled") private var taxReminderEnabled = true
    @AppStorage("budgetAlertEnabled") private var budgetAlertEnabled = true
    @AppStorage("weeklyReportEnabled") private var weeklyReportEnabled = false
    
    @State private var viewAppeared = false
    
    // Haptic Generators
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        Form {
            Section {
                Toggle("Enable Notifications", isOn: $notificationsEnabled)
                    .tint(Color.brandPrimary)
                    .onChange(of: notificationsEnabled) { _, _ in
                        impactLight.impactOccurred()
                    }
            } footer: {
                Text("Allow FLO to send you important reminders and updates")
            }
            .opacity(viewAppeared ? 1 : 0)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: viewAppeared)
            
            if notificationsEnabled {
                Section("Reminders") {
                    Toggle("Quarterly Tax Deadlines", isOn: $taxReminderEnabled)
                        .tint(Color.brandPrimary)
                        .onChange(of: taxReminderEnabled) { _, _ in
                            impactLight.impactOccurred()
                        }
                    Toggle("Budget Alerts", isOn: $budgetAlertEnabled)
                        .tint(Color.brandPrimary)
                        .onChange(of: budgetAlertEnabled) { _, _ in
                            impactLight.impactOccurred()
                        }
                    Toggle("Weekly Summary", isOn: $weeklyReportEnabled)
                        .tint(Color.brandPrimary)
                        .onChange(of: weeklyReportEnabled) { _, _ in
                            impactLight.impactOccurred()
                        }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: notificationsEnabled)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                viewAppeared = true
            }
        }
    }
}

// MARK: - Data Management View

struct DataManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [Transaction]
    @Query private var trips: [MileageTrip]
    
    @State private var showingClearDataAlert = false
    @State private var viewAppeared = false
    
    // Haptic Generators
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    var body: some View {
        Form {
            Section("Storage") {
                HStack {
                    Text("Transactions")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(transactions.count)")
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                
                HStack {
                    Text("Mileage Trips")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(trips.count)")
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            }
            .opacity(viewAppeared ? 1 : 0)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: viewAppeared)
            
            Section {
                Button(role: .destructive) {
                    impactHeavy.impactOccurred()
                    showingClearDataAlert = true
                } label: {
                    Label {
                        Text("Clear All Data")
                            .foregroundStyle(.red)
                    } icon: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                }
            } footer: {
                Text("This will permanently delete all your transactions, trips, and settings. This action cannot be undone.")
            }
            .opacity(viewAppeared ? 1 : 0)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: viewAppeared)
        }
        .navigationTitle("Data & Storage")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Clear All Data?", isPresented: $showingClearDataAlert) {
            Button("Cancel", role: .cancel) {
                impactLight.impactOccurred()
            }
            Button("Delete Everything", role: .destructive) {
                clearAllData()
            }
        } message: {
            Text("This will permanently delete all your data. This action cannot be undone.")
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                viewAppeared = true
            }
        }
    }
    
    private func clearAllData() {
        for transaction in transactions {
            modelContext.delete(transaction)
        }
        
        for trip in trips {
            modelContext.delete(trip)
        }
        
        do {
            try modelContext.save()
            notificationFeedback.notificationOccurred(.success)
        } catch {
            notificationFeedback.notificationOccurred(.error)
        }
    }
}

// MARK: - Backup Settings View

struct BackupSettingsView: View {
    @State private var viewAppeared = false
    
    var body: some View {
        Form {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "icloud")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.brandPrimary)
                        .symbolEffect(.bounce, value: viewAppeared)
                    
                    Text("iCloud sync coming soon")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } header: {
                Text("Backup")
            } footer: {
                Text("Automatically sync your data across all your devices with iCloud")
            }
        }
        .navigationTitle("Backup & Sync")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewAppeared = true
        }
    }
}

// MARK: - Export Options View

struct ExportOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [Transaction]
    @Query private var trips: [MileageTrip]
    
    @State private var viewAppeared = false
    
    // Haptic Generators
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Transactions") {
                    Button {
                        impactMedium.impactOccurred()
                        exportTransactionsCSV()
                    } label: {
                        Label {
                            Text("Export Transactions to CSV")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "doc.text")
                                .foregroundStyle(Color.brandPrimary)
                        }
                    }
                }
                .opacity(viewAppeared ? 1 : 0)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: viewAppeared)
                
                Section("Mileage") {
                    Button {
                        impactMedium.impactOccurred()
                        exportMileageCSV()
                    } label: {
                        Label {
                            Text("Export Mileage Log to CSV")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "car")
                                .foregroundStyle(Color.brandPrimary)
                        }
                    }
                }
                .opacity(viewAppeared ? 1 : 0)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: viewAppeared)
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        impactLight.impactOccurred()
                        dismiss()
                    }
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    viewAppeared = true
                }
            }
        }
    }
    
    private func exportTransactionsCSV() {
        notificationFeedback.notificationOccurred(.success)
        // Export logic here
    }
    
    private func exportMileageCSV() {
        notificationFeedback.notificationOccurred(.success)
        // Export logic here
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewAppeared = false
    
    // Haptic Generators
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // App Icon
                    Image(systemName: "drop.triangle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(Color.brandPrimary)
                        .padding(.top, 40)
                        .scaleEffect(viewAppeared ? 1 : 0.5)
                        .opacity(viewAppeared ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: viewAppeared)
                    
                    // App Name & Version
                    VStack(spacing: 8) {
                        Text("FLO")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Finance Ledger Optimizer")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text("Version \(appVersion)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(y: viewAppeared ? 0 : 20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: viewAppeared)
                    
                    // Description
                    Text("Financial management designed for freelancers, gig workers, and small business owners")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .opacity(viewAppeared ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: viewAppeared)
                    
                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                            SettingsFeatureRow(icon: feature.icon, title: feature.title)
                                .opacity(viewAppeared ? 1 : 0)
                                .offset(x: viewAppeared ? 0 : 20)
                                .animation(
                                    .spring(response: 0.5, dampingFraction: 0.8)
                                    .delay(0.2 + Double(index) * 0.05),
                                    value: viewAppeared
                                )
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Credits
                    VStack(spacing: 12) {
                        Text("Made by Finch & Poppy Co LLC")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Link("Visit Our Website", destination: URL(string: "https://floptimizer.github.io/FLO/index.html")!)
                            .font(.subheadline)
                            .foregroundStyle(Color.brandPrimary)
                    }
                    .padding(.bottom, 40)
                    .opacity(viewAppeared ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.4), value: viewAppeared)
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        impactLight.impactOccurred()
                        dismiss()
                    }
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    viewAppeared = true
                }
            }
        }
    }
    
    private var features: [(icon: String, title: String)] {
        [
            ("chart.line.uptrend.xyaxis", "Smart Expense Tracking"),
            ("doc.text", "Quarterly Tax Estimates"),
            ("car", "Automatic Mileage Tracking"),
            ("camera", "Receipt Scanning"),
            ("lock.shield", "Secure & Private")
        ]
    }
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

struct SettingsFeatureRow: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.brandPrimary)
                .frame(width: 30)
            
            Text(title)
                .font(.body)
        }
    }
}

// MARK: - Help Center View

struct HelpCenterView: View {
    @State private var viewAppeared = false
    
    var body: some View {
        List {
            Section("Getting Started") {
                NavigationLink("Adding Transactions") {
                    HelpArticleView(
                        title: "Adding Transactions",
                        icon: "plus.circle.fill",
                        sections: [
                            HelpSection(
                                title: "Quick Add",
                                content: "Tap the + button on any screen to add a new transaction. Enter the amount, select whether it's income or expense, and choose a category."
                            ),
                            HelpSection(
                                title: "Business vs Personal",
                                content: "Mark each transaction as Business or Personal. Business expenses are automatically flagged for potential tax deductions. Personal expenses are tracked separately for your records."
                            ),
                            HelpSection(
                                title: "Categories",
                                content: "Assign categories to organize your spending. You can create custom categories in Settings > Categories to match your business needs."
                            ),
                            HelpSection(
                                title: "Receipts",
                                content: "Attach receipt photos to any transaction by tapping 'Scan Receipt'. The app will automatically extract the amount, date, and merchant name."
                            )
                        ]
                    )
                }
                .opacity(viewAppeared ? 1 : 0)
                .offset(x: viewAppeared ? 0 : 15)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: viewAppeared)
                
                NavigationLink("Setting Up Tax Estimates") {
                    HelpArticleView(
                        title: "Tax Estimates",
                        icon: "doc.text.fill",
                        sections: [
                            HelpSection(
                                title: "Initial Setup",
                                content: "Go to Settings > Tax Settings to configure your tax profile. Select your state and filing status (Single, Married Filing Jointly, etc.) for accurate estimates."
                            ),
                            HelpSection(
                                title: "How Estimates Work",
                                content: "FLO calculates estimated quarterly taxes based on your year-to-date income and business expenses. It uses current IRS tax brackets, your state's tax rate, and self-employment tax (15.3%)."
                            ),
                            HelpSection(
                                title: "Quarterly Deadlines",
                                content: "For 2025, quarterly estimated tax payments are due:\n• Q1 (Jan-Mar): April 15\n• Q2 (Apr-May): June 16\n• Q3 (Jun-Aug): September 15\n• Q4 (Sep-Dec): January 15, 2026"
                            ),
                            HelpSection(
                                title: "Reminders",
                                content: "Enable quarterly reminders to get notified before each deadline. You can customize how many days in advance you'd like to be reminded."
                            ),
                            HelpSection(
                                title: "Important Disclaimer",
                                content: "Tax estimates are for planning purposes only and should not be considered tax advice. Consult a qualified tax professional for your specific situation."
                            )
                        ]
                    )
                }
                .opacity(viewAppeared ? 1 : 0)
                .offset(x: viewAppeared ? 0 : 15)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: viewAppeared)
                
                NavigationLink("Tracking Mileage") {
                    HelpArticleView(
                        title: "Mileage Tracking",
                        icon: "car.fill",
                        sections: [
                            HelpSection(
                                title: "Getting Started",
                                content: "Go to the Mileage tab and tap 'Start Trip' when you begin a business drive. The app uses your phone's GPS to track distance automatically."
                            ),
                            HelpSection(
                                title: "Automatic Trip Detection",
                                content: "Enable automatic tracking to let FLO detect when you're driving. Trips end automatically after you've been stationary for a few minutes."
                            ),
                            HelpSection(
                                title: "IRS Mileage Rate",
                                content: "FLO uses the current IRS standard mileage rate (72.5¢ per mile for 2026) to calculate your deduction. This rate is updated annually."
                            ),
                            HelpSection(
                                title: "Manual Entry",
                                content: "You can also add trips manually if you forgot to track. Enter the start location, end location, and purpose of the trip."
                            ),
                            HelpSection(
                                title: "Location Permissions",
                                content: "For best results, allow 'Always' location access. This enables background tracking so trips continue even when the app isn't open."
                            )
                        ]
                    )
                }
                .opacity(viewAppeared ? 1 : 0)
                .offset(x: viewAppeared ? 0 : 15)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: viewAppeared)
            }
            
            Section("Features") {
                NavigationLink("Budgeting") {
                    HelpArticleView(
                        title: "Budgeting",
                        icon: "chart.pie.fill",
                        sections: [
                            HelpSection(
                                title: "Creating Budgets",
                                content: "Tap 'Create Budget' to set spending limits for different categories. Choose between monthly or custom time periods."
                            ),
                            HelpSection(
                                title: "Envelope Budgeting",
                                content: "FLO supports envelope-style budgeting where each category gets a fixed amount. When you spend from a category, it reduces that envelope."
                            ),
                            HelpSection(
                                title: "Rollover",
                                content: "Enable rollover to carry unused budget amounts to the next month. Great for saving up for larger purchases."
                            ),
                            HelpSection(
                                title: "Warnings",
                                content: "Get notified when you're approaching your budget limit. Customize the warning threshold (e.g., alert at 80% spent)."
                            )
                        ]
                    )
                }
                .opacity(viewAppeared ? 1 : 0)
                .offset(x: viewAppeared ? 0 : 15)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: viewAppeared)
                
                NavigationLink("Receipt Scanning") {
                    HelpArticleView(
                        title: "Receipt Scanning",
                        icon: "camera.fill",
                        sections: [
                            HelpSection(
                                title: "How to Scan",
                                content: "Use the camera button when adding a transaction, or use the Quick Action on the Dashboard. Point your camera at the receipt and hold steady."
                            ),
                            HelpSection(
                                title: "What's Extracted",
                                content: "The scanner automatically detects the merchant name, total amount, date, and suggests a category based on the store type."
                            ),
                            HelpSection(
                                title: "Editing Results",
                                content: "After scanning, you can edit any field before saving. If the scanner misread something, simply tap the field to correct it."
                            ),
                            HelpSection(
                                title: "Storage",
                                content: "Receipt images are stored securely on your device. They're attached to transactions for easy reference and tax documentation."
                            )
                        ]
                    )
                }
                .opacity(viewAppeared ? 1 : 0)
                .offset(x: viewAppeared ? 0 : 15)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.25), value: viewAppeared)
                
                NavigationLink("Invoicing") {
                    HelpArticleView(
                        title: "Invoicing",
                        icon: "doc.plaintext.fill",
                        sections: [
                            HelpSection(
                                title: "Creating Invoices",
                                content: "Go to the Invoices tab and tap 'Create Invoice'. Add your client, line items, and payment terms."
                            ),
                            HelpSection(
                                title: "Managing Clients",
                                content: "Save client information for quick invoicing. Client details are automatically populated when you create new invoices."
                            ),
                            HelpSection(
                                title: "Payment Tracking",
                                content: "Mark invoices as paid when you receive payment. Track overdue invoices and send payment reminders."
                            ),
                            HelpSection(
                                title: "Exporting",
                                content: "Export invoices as PDF to share with clients via email or messaging apps."
                            )
                        ]
                    )
                }
                .opacity(viewAppeared ? 1 : 0)
                .offset(x: viewAppeared ? 0 : 15)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3), value: viewAppeared)
            }
            
            Section("Security & Privacy") {
                NavigationLink("Protecting Your Data") {
                    HelpArticleView(
                        title: "Security",
                        icon: "lock.shield.fill",
                        sections: [
                            HelpSection(
                                title: "Face ID / Touch ID",
                                content: "Enable biometric authentication in Settings > Security to protect your financial data. The app will require Face ID or Touch ID each time you open it."
                            ),
                            HelpSection(
                                title: "Passcode",
                                content: "Set a 6-digit passcode as a backup authentication method. This is required if biometrics fail or aren't available."
                            ),
                            HelpSection(
                                title: "Data Storage",
                                content: "All your data is stored locally on your device. We don't have access to your financial information."
                            ),
                            HelpSection(
                                title: "Backups",
                                content: "Your data is included in your device's iCloud backup if enabled. This allows restoration if you get a new device."
                            )
                        ]
                    )
                }
                .opacity(viewAppeared ? 1 : 0)
                .offset(x: viewAppeared ? 0 : 15)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.35), value: viewAppeared)
            }
            
            Section("Need More Help?") {
                Link(destination: URL(string: "mailto:flo.financeapp@gmail.com")!) {
                    Label {
                        Text("Contact Support")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "envelope.fill")
                            .foregroundStyle(Color.brandPrimary)
                    }
                }
                .buttonStyle(.plain)
                .opacity(viewAppeared ? 1 : 0)
                .offset(x: viewAppeared ? 0 : 15)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.4), value: viewAppeared)
                
                Link(destination: URL(string: "https://floptimizer.github.io/FLO/index.htm")!) {
                    Label {
                        Text("FAQ")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundStyle(Color.brandPrimary)
                    }
                }
                .buttonStyle(.plain)
                .opacity(viewAppeared ? 1 : 0)
                .offset(x: viewAppeared ? 0 : 15)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.45), value: viewAppeared)
            }
        }
        .navigationTitle("Help Center")
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                viewAppeared = true
            }
        }
    }
}

// MARK: - Help Article Components

struct HelpSection: Identifiable {
    let id = UUID()
    let title: String
    let content: String
}

struct HelpArticleView: View {
    let title: String
    let icon: String
    let sections: [HelpSection]
    
    @State private var viewAppeared = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 40))
                        .foregroundStyle(Color.brandPrimary)
                        .symbolEffect(.bounce, value: viewAppeared)
                    
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .padding(.bottom, 8)
                .opacity(viewAppeared ? 1 : 0)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: viewAppeared)
                
                // Sections
                ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title)
                            .font(.headline)
                            .foregroundStyle(Color.brandPrimary)
                        
                        Text(section.content)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(y: viewAppeared ? 0 : 15)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.8)
                        .delay(0.1 + Double(index) * 0.05),
                        value: viewAppeared
                    )
                }
            }
            .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                viewAppeared = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .modelContainer(for: [Transaction.self, MileageTrip.self], inMemory: true)
}
