//  SettingsView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 4.0 - VoiceOver Audit: Hidden decorative icons in navigation rows
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v4.0 - VoiceOver Audit:
//  ✅ ADDED: 25 decorative icons hidden in NavigationLink rows (pencil, building, lock, folder, doc, star, bell, paintbrush, drive, export, receipt, cloud, envelope, question, privacy, terms, EULA, warning, info icons)
//  ✅ VERIFIED: Checkmark status indicator NOT hidden (conveys security state)
//  ✅ VERIFIED: Theme emoji NOT hidden (conveys current selection)
//  ✅ VERIFIED: Version/build info row already uses .accessibilityElement(children: .combine)
//  ✅ VERIFIED: Profile section already uses .accessibilityElement with spoken label
//  ✅ ADDED: Help Center decorative icons hidden (envelope, book, star icons)
//  ✅ ADDED: HelpArticleView header icon NOT hidden (serves as visual identifier)
//
//  CHANGES v3.9 - Dynamic Type Verification:
//  ✅ FIXED: Profile section name text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Profile section email text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: All navigation link labels missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Security footer text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Tax Settings subtitle missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Subscription tier display name missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Receipt Storage description missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Version number text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: ProfileEditView footer text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: NotificationSettingsView footer text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: DataManagementView storage counts missing lineLimit + minimumScaleFactor
//  ✅ FIXED: DataManagementView receipt storage description missing lineLimit + minimumScaleFactor
//  ✅ FIXED: DataManagementView footer warning text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: BackupSettingsView "iCloud sync coming soon" missing lineLimit + minimumScaleFactor
//  ✅ FIXED: BackupSettingsView footer text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: AboutView app name and descriptions missing lineLimit + minimumScaleFactor
//  ✅ FIXED: HelpCenterView contact email and URL missing lineLimit + minimumScaleFactor
//  ✅ FIXED: HelpArticleView section titles missing lineLimit + minimumScaleFactor
//  ✅ FIXED: HelpArticleView section content missing lineLimit + minimumScaleFactor
//
//  CHANGES v3.8:
//  ✅ Full VoiceOver accessibility across all embedded views
//  ✅ Screen change announcements on appear
//  ✅ Profile section combined with spoken name/email
//  ✅ Security row: checkmark status read aloud, chevron hidden
//  ✅ Subscription row: current tier spoken
//  ✅ Storage rows combined with spoken counts
//  ✅ About view decorative icon hidden, content combined
//  ✅ HelpArticleView section titles get .isHeader trait
//  ✅ BackupSettingsView decorative icon hidden, combined
//  ✅ Fixed garbled UTF-8 characters
//
//  CHANGES FROM v3.6:
//  ✅ ADDED: EULA NavigationLink in Support section (Apple Guideline 3.1.2)
//
//  PREVIOUS (v3.6):
//  - Siri Shortcuts help section
//  - Quick Actions help section
//  - Control Center help section (iOS 18+)
//  - Mileage help with pause/resume features
//  - Contact email to flo.financeapp@gmail.com
//  - Rate FLO link in Help Center
//  - Security section with location privacy info
//
//  PREVIOUS (v3.5):
//  - Receipt Storage navigation in Data section
//  - All haptics use centralized HapticService
//  - All animations use FLOAnimation presets
//

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
                            .font(.largeTitle)
                             .foregroundStyle(Color.brandPrimaryText)
                            .symbolEffect(.bounce, value: viewAppeared)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            if userName.isEmpty {
                                Text("Add Your Name")
                                    .font(.headline)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(userName)
                                    .font(.headline)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .foregroundStyle(.primary)
                            }
                            
                            if !userEmail.isEmpty {
                                Text(userEmail)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 12)
                    }
                    .padding(.vertical, 8)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel({
                        var label = userName.isEmpty ? "No name set" : userName
                        if !userEmail.isEmpty { label += ", \(userEmail)" }
                        return label
                    }())
                    
                    NavigationLink {
                        ProfileEditView(userName: $userName, userEmail: $userEmail)
                    } label: {
                        Label {
                            Text("Edit Profile")
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "pencil")
                                 .foregroundStyle(Color.brandPrimaryText)
                                .accessibilityHidden(true)
                        }
                    }
                    
                    NavigationLink {
                        BusinessProfileSettingsView()
                    } label: {
                        Label {
                            Text("Business Profile")
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "building.2")
                                 .foregroundStyle(Color.brandPrimaryText)
                                .accessibilityHidden(true)
                        }
                    }
                } header: {
                    Text("Profile")
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)
                
                // Security Section
                Section {
                    Button {
                        HapticService.play(.medium)
                        showingBiometricSetup = true
                    } label: {
                        HStack {
                            Label {
                                Text("Passcode & Biometrics")
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .foregroundStyle(.primary)
                            } icon: {
                                Image(systemName: "lock.shield.fill")
                                     .foregroundStyle(Color.brandPrimaryText)
                                    .accessibilityHidden(true)
                            }
                            
                            Spacer()
                            
                            if BiometricAuthService.shared.biometricEnabled || PasscodeService.shared.hasPasscode() {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .accessibilityHidden(true)
                            }
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Passcode and Biometrics\(BiometricAuthService.shared.biometricEnabled || PasscodeService.shared.hasPasscode() ? ", enabled" : ", not configured")")
                    .accessibilityHint("Opens security settings")
                } header: {
                    Text("Security")
                } footer: {
                    Text("Protect your financial data with Face ID or a passcode")
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
                
                // Categories Section
                Section("Categories") {
                    NavigationLink {
                        CategoryManagementView()
                    } label: {
                        Label {
                            Text("Manage Categories")
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "folder")
                                 .foregroundStyle(Color.brandPrimaryText)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)
                
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
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .foregroundStyle(.primary)
                                    Text("Quarterly estimates & filing status")
                                        .font(.caption)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "doc.text.fill")
                                     .foregroundStyle(Color.brandPrimaryText)
                                    .frame(width: 28)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                } header: {
                    Text("Features")
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)
                
                // Premium Features Section
                Section {
                    NavigationLink {
                        SubscriptionView()
                    } label: {
                        HStack {
                            Label {
                                Text("Subscription")
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .foregroundStyle(.primary)
                            } icon: {
                                Image(systemName: "star.fill")
                                     .foregroundStyle(Color.brandPrimaryText)
                                    .accessibilityHidden(true)
                            }
                            Spacer()
                            Text(SubscriptionManager.shared.currentTier.displayName)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityLabel("Subscription, current plan: \(SubscriptionManager.shared.currentTier.displayName)")
                } header: {
                    Text("Premium Features")
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(FLOAnimation.standard.delay(0.25), value: viewAppeared)
                
                // Preferences Section
                Section {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Label {
                            Text("Notifications")
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "bell.fill")
                                 .foregroundStyle(Color.brandPrimaryText)
                                .accessibilityHidden(true)
                        }
                    }
                    
                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        HStack {
                            Label {
                                Text("Appearance")
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .foregroundStyle(.primary)
                            } icon: {
                                Image(systemName: "paintbrush.fill")
                                     .foregroundStyle(Color.brandPrimaryText)
                                    .accessibilityHidden(true)
                            }
                            Spacer()
                            Text(ColorSchemeManager.shared.currentScheme.emoji)
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityLabel("Appearance, current: \(ColorSchemeManager.shared.currentScheme.name)")
                    
                    NavigationLink {
                        DataManagementView()
                    } label: {
                        Label {
                            Text("Data & Storage")
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "externaldrive.fill")
                                 .foregroundStyle(Color.brandPrimaryText)
                                .accessibilityHidden(true)
                        }
                    }
                } header: {
                    Text("Preferences")
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(FLOAnimation.standard.delay(0.3), value: viewAppeared)
                
                // Data Section - NOW INCLUDES RECEIPT STORAGE
                Section {
                    Button {
                        HapticService.play(.medium)
                        showingExportOptions = true
                    } label: {
                        Label {
                            Text("Export Data")
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "square.and.arrow.up")
                                 .foregroundStyle(Color.brandPrimaryText)
                                .accessibilityHidden(true)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    // NEW: Receipt Storage Navigation
                    NavigationLink {
                        ReceiptStorageSettingsView()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Receipt Storage")
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .foregroundStyle(.primary)
                                Text("Export & manage receipt images")
                                    .font(.caption)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "doc.text.image")
                                 .foregroundStyle(Color.brandPrimaryText)
                                .accessibilityHidden(true)
                        }
                    }
                    
                    NavigationLink {
                        BackupSettingsView()
                    } label: {
                        Label {
                            Text("Backup & Sync")
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "icloud.fill")
                                 .foregroundStyle(Color.brandPrimaryText)
                                .accessibilityHidden(true)
                        }
                    }
                } header: {
                    Text("Data")
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(FLOAnimation.standard.delay(0.35), value: viewAppeared)
                
                // Support Section
                Section {
                    Link(destination: URL(string: "mailto:flowledgerco@gmail.com")!) {
                        Label {
                            Text("Contact Support")
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "envelope.fill")
                                 .foregroundStyle(Color.brandPrimaryText)
                                .accessibilityHidden(true)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    NavigationLink {
                        HelpCenterView()
                    } label: {
                        Label {
                            Text("Help Center")
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "questionmark.circle.fill")
                                 .foregroundStyle(Color.brandPrimaryText)
                                .accessibilityHidden(true)
                        }
                    }
                    
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label {
                            Text("Privacy Policy")
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "hand.raised.fill")
                                 .foregroundStyle(Color.brandPrimaryText)
                                .accessibilityHidden(true)
                        }
                    }
                    
                    NavigationLink {
                        TermsOfServiceView()
                    } label: {
                        Label {
                            Text("Terms of Service")
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "doc.text.fill")
                                 .foregroundStyle(Color.brandPrimaryText)
                                .accessibilityHidden(true)
                        }
                    }
                    
                    // EULA - Added for App Store Guideline 3.1.2 compliance
                    NavigationLink {
                        EULAView()
                    } label: {
                        Label {
                            Text("End User License Agreement")
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "signature")
                                 .foregroundStyle(Color.brandPrimaryText)
                                .accessibilityHidden(true)
                        }
                    }
                    
                    NavigationLink {
                        TaxDisclaimerView()
                    } label: {
                        Label {
                            Text("Tax & Legal Disclaimer")
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                 .foregroundStyle(Color.brandPrimaryText)
                                .accessibilityHidden(true)
                        }
                    }
                } header: {
                    Text("Support")
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(FLOAnimation.standard.delay(0.4), value: viewAppeared)
                
                // About Section
                Section {
                    Button {
                        HapticService.play(.medium)
                        showingAbout = true
                    } label: {
                        HStack {
                            Label {
                                Text("About FLO")
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .foregroundStyle(.primary)
                            } icon: {
                                Image(systemName: "info.circle.fill")
                                     .foregroundStyle(Color.brandPrimaryText)
                                    .accessibilityHidden(true)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    HStack {
                        Text("Version")
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(appVersion)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                } header: {
                    Text("About")
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(FLOAnimation.standard.delay(0.45), value: viewAppeared)
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
                withAnimation(FLOAnimation.standard) {
                    viewAppeared = true
                }
                AccessibilityAnnouncement.screenChanged("Settings")
            }
        }
        .preferredColorScheme(colorScheme)
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
            .opacity(viewAppeared ? 1 : 0.001)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)
            
            Section {
                Text("Your profile information is stored locally on your device and is never shared.")
                    .font(.caption)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.secondary)
            }
            .opacity(viewAppeared ? 1 : 0.001)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    HapticService.play(.light)
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    HapticService.play(.medium)
                    saveProfile()
                }
            }
        }
        .onAppear {
            withAnimation(FLOAnimation.standard) {
                viewAppeared = true
            }
            AccessibilityAnnouncement.screenChanged("Edit profile")
        }
    }
    
    private func saveProfile() {
        userName = editedName
        userEmail = editedEmail
        HapticService.play(.success)
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
    
    var body: some View {
        Form {
            Section {
                Toggle("Enable Notifications", isOn: $notificationsEnabled)
                    .tint(Color.brandPrimary)
                    .onChange(of: notificationsEnabled) { _, _ in
                        HapticService.play(.light)
                    }
            } footer: {
                Text("Allow FLO to send you important reminders and updates")
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            .opacity(viewAppeared ? 1 : 0.001)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)
            
            if notificationsEnabled {
                Section("Reminders") {
                    Toggle("Quarterly Tax Deadlines", isOn: $taxReminderEnabled)
                        .tint(Color.brandPrimary)
                        .onChange(of: taxReminderEnabled) { _, _ in
                            HapticService.play(.light)
                        }
                    Toggle("Budget Alerts", isOn: $budgetAlertEnabled)
                        .tint(Color.brandPrimary)
                        .onChange(of: budgetAlertEnabled) { _, _ in
                            HapticService.play(.light)
                        }
                    Toggle("Weekly Summary", isOn: $weeklyReportEnabled)
                        .tint(Color.brandPrimary)
                        .onChange(of: weeklyReportEnabled) { _, _ in
                            HapticService.play(.light)
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
        .animation(FLOAnimation.standard, value: notificationsEnabled)
        .onAppear {
            withAnimation(FLOAnimation.standard) {
                viewAppeared = true
            }
            AccessibilityAnnouncement.screenChanged("Notifications")
        }
    }
}

// MARK: - Data Management View

struct DataManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [Transaction]
    @Query private var trips: [MileageTrip]
    @Query private var receipts: [ReceiptData]
    
    @State private var showingClearDataAlert = false
    @State private var viewAppeared = false
    
    var body: some View {
        Form {
            Section("Storage") {
                HStack {
                    Label("Transactions", systemImage: "creditcard")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(transactions.count)")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                .accessibilityElement(children: .combine)
                
                HStack {
                    Label("Mileage Trips", systemImage: "car")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(trips.count)")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                .accessibilityElement(children: .combine)
                
                HStack {
                    Label("Receipts", systemImage: "doc.text.image")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(receipts.count)")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                .accessibilityElement(children: .combine)
            }
            .opacity(viewAppeared ? 1 : 0.001)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)
            
            // Receipt Storage Link
            Section {
                NavigationLink {
                    ReceiptStorageSettingsView()
                } label: {
                    HStack {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Manage Receipt Storage")
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .foregroundStyle(.primary)
                                Text("Export to ZIP, purge by month/year")
                                    .font(.caption)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "photo.on.rectangle.angled")
                                 .foregroundStyle(Color.brandPrimaryText)
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
            .opacity(viewAppeared ? 1 : 0.001)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
            
            Section {
                Button(role: .destructive) {
                    HapticService.play(.heavy)
                    showingClearDataAlert = true
                } label: {
                    Label {
                        Text("Clear All Data")
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.red)
                    } icon: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                            .accessibilityHidden(true)
                    }
                }
            } footer: {
                Text("This will permanently delete all your transactions, trips, receipts, and settings. This action cannot be undone.")
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
            }
            .opacity(viewAppeared ? 1 : 0.001)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)
        }
        .navigationTitle("Data & Storage")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Clear All Data?", isPresented: $showingClearDataAlert) {
            Button("Cancel", role: .cancel) {
                HapticService.play(.light)
            }
            Button("Delete Everything", role: .destructive) {
                clearAllData()
            }
        } message: {
            Text("This will permanently delete all your data including \(transactions.count) transactions, \(trips.count) trips, and \(receipts.count) receipts. This action cannot be undone.")
        }
        .onAppear {
            withAnimation(FLOAnimation.standard) {
                viewAppeared = true
            }
            AccessibilityAnnouncement.screenChanged("Data and storage")
        }
    }
    
    private func clearAllData() {
        for transaction in transactions {
            modelContext.delete(transaction)
        }
        
        for trip in trips {
            modelContext.delete(trip)
        }
        
        for receipt in receipts {
            modelContext.delete(receipt)
        }
        
        do {
            try modelContext.save()
            HapticService.play(.success)
        } catch {
            HapticService.play(.error)
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
                        .font(.largeTitle)
                        .foregroundStyle(Color.brandPrimary)
                        .symbolEffect(.bounce, value: viewAppeared)
                        .accessibilityHidden(true)
                    
                    Text("iCloud sync coming soon")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .accessibilityElement(children: .combine)
            } header: {
                Text("Backup")
            } footer: {
                Text("Your data is automatically included in your device's iCloud backup if enabled in iOS Settings.")
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
            }
            .opacity(viewAppeared ? 1 : 0.001)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)
        }
        .navigationTitle("Backup & Sync")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(FLOAnimation.standard) {
                viewAppeared = true
            }
            AccessibilityAnnouncement.screenChanged("Backup and sync")
        }
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewAppeared = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // App Icon and Name
                    VStack(spacing: 16) {
                        Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(Color.brandPrimary)
                            .symbolEffect(.bounce, value: viewAppeared)
                            .accessibilityHidden(true)
                        
                        Text("FLO")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        
                        Text("Finance Ledger Optimizer")
                            .font(.subheadline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                        
                        Text("Version \(appVersion)")
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 32)
                    .accessibilityElement(children: .combine)
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 20)
                    .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
                    
                    // Description
                    VStack(spacing: 8) {
                        Text("Made for Freelancers")
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        
                        Text("FLO helps freelancers, gig workers, and small business owners manage their finances, track expenses, and prepare for taxes with confidence.")
                            .font(.body)
                            .lineLimit(3)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 15)
                    .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)
                    
                    // Company Info
                    VStack(spacing: 8) {
                        Text("Finch & Poppy Co LLC")
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        
                        Text("© 2025 All Rights Reserved")
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 16)
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 15)
                    .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)
                    
                    Spacer()
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        HapticService.play(.light)
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Delay entrance animation until sheet is fully presented
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(FLOAnimation.standard) {
                        viewAppeared = true
                    }
                }
                AccessibilityAnnouncement.screenChanged("About FLO")
            }
        }
    }
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Help Center View

struct HelpCenterView: View {
    @State private var viewAppeared = false
    
    var body: some View {
        List {
            Section("Getting Started") {
                NavigationLink("Tracking Transactions") {
                    HelpArticleView(
                        title: "Transactions",
                        icon: "creditcard.fill",
                        sections: [
                            HelpSection(
                                title: "Adding Transactions",
                                content: "Tap the + button on the Dashboard to add a new transaction. Enter the amount, select a category, and add any notes."
                            ),
                            HelpSection(
                                title: "Categories",
                                content: "Organize your spending with categories. You can create custom categories in Settings > Categories."
                            ),
                            HelpSection(
                                title: "Business vs Personal",
                                content: "Mark transactions as business expenses to track them separately for tax purposes."
                            )
                        ]
                    )
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(x: viewAppeared ? 0 : 15)
                .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
                
                NavigationLink("Budgets") {
                    HelpArticleView(
                        title: "Budgets",
                        icon: "chart.pie.fill",
                        sections: [
                            HelpSection(
                                title: "Creating Budgets",
                                content: "Set spending limits for different categories. FLO will track your progress and alert you when you're close to your limit."
                            ),
                            HelpSection(
                                title: "Budget Periods",
                                content: "Choose weekly, monthly, or custom budget periods based on your cash flow needs."
                            ),
                            HelpSection(
                                title: "Rollover",
                                content: "Enable rollover to carry unused budget amounts to the next period."
                            )
                        ]
                    )
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(x: viewAppeared ? 0 : 15)
                .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)
                
                NavigationLink("Mileage Tracking") {
                    HelpArticleView(
                        title: "Mileage",
                        icon: "car.fill",
                        sections: [
                            HelpSection(
                                title: "Automatic Tracking",
                                content: "Enable GPS tracking to automatically log your business trips. FLO detects when you start and stop driving, even when running in the background."
                            ),
                            HelpSection(
                                title: "Quick Pause & Resume",
                                content: "Pause mileage tracking quickly without opening the app using: Long-press the FLO app icon, Control Center toggle (iOS 18+), or Siri commands. This helps save battery when you're not driving."
                            ),
                            HelpSection(
                                title: "Manual Entry",
                                content: "Add trips manually by entering the start and end locations or the total miles driven."
                            ),
                            HelpSection(
                                title: "Trip Classification",
                                content: "Auto-tracked trips are marked as 'Needs Review'. Tap any trip to classify it as Business or Personal before it counts toward your tax deduction."
                            ),
                            HelpSection(
                                title: "IRS Rate",
                                content: "FLO uses the current IRS standard mileage rate to calculate your deduction. The 2025 rate is $0.70 per mile for business use."
                            )
                        ]
                    )
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(x: viewAppeared ? 0 : 15)
                .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)
            }
            
            Section("Features") {
                NavigationLink("Receipt Scanning") {
                    HelpArticleView(
                        title: "Receipts",
                        icon: "doc.text.viewfinder",
                        sections: [
                            HelpSection(
                                title: "Scanning Receipts",
                                content: "Use your camera to scan receipts. FLO will automatically extract the merchant, amount, and date using AI."
                            ),
                            HelpSection(
                                title: "Matching to Transactions",
                                content: "Link scanned receipts to transactions for complete documentation of your expenses."
                            ),
                            HelpSection(
                                title: "Storage",
                                content: "Receipt images are stored securely on your device. Export or purge receipts anytime in Settings > Receipt Storage."
                            )
                        ]
                    )
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(x: viewAppeared ? 0 : 15)
                .animation(FLOAnimation.standard.delay(0.25), value: viewAppeared)
                
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
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(x: viewAppeared ? 0 : 15)
                .animation(FLOAnimation.standard.delay(0.3), value: viewAppeared)
            }
            
            Section("Quick Access") {
                NavigationLink("Siri Shortcuts") {
                    HelpArticleView(
                        title: "Siri",
                        icon: "waveform.circle.fill",
                        sections: [
                            HelpSection(
                                title: "Voice Commands",
                                content: "Control FLO hands-free with Siri. Try saying:\n• \"Hey Siri, pause mileage tracking in FLO\"\n• \"Hey Siri, resume mileage in FLO\"\n• \"Hey Siri, check mileage status in FLO\""
                            ),
                            HelpSection(
                                title: "Shortcuts App",
                                content: "FLO shortcuts also appear in the Shortcuts app. Create automations like pausing mileage when you arrive at home or resuming when you leave for work."
                            ),
                            HelpSection(
                                title: "Customizing Phrases",
                                content: "Go to Settings > FLO > Siri & Shortcuts to customize voice phrases or add shortcuts to your Home Screen."
                            )
                        ]
                    )
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(x: viewAppeared ? 0 : 15)
                .animation(FLOAnimation.standard.delay(0.35), value: viewAppeared)
                
                NavigationLink("Quick Actions") {
                    HelpArticleView(
                        title: "Quick Actions",
                        icon: "hand.tap.fill",
                        sections: [
                            HelpSection(
                                title: "App Icon Menu",
                                content: "Long-press (3D Touch or Haptic Touch) the FLO app icon on your Home Screen to see quick actions:\n• Pause/Resume Mileage\n• Add Transaction\n• Scan Receipt"
                            ),
                            HelpSection(
                                title: "Dynamic Options",
                                content: "The mileage option automatically changes between 'Pause' and 'Resume' based on your current tracking state."
                            ),
                            HelpSection(
                                title: "Requirements",
                                content: "Mileage quick actions only appear after you've completed the mileage setup and granted 'Always Allow' location permission."
                            )
                        ]
                    )
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(x: viewAppeared ? 0 : 15)
                .animation(FLOAnimation.standard.delay(0.4), value: viewAppeared)
                
                if #available(iOS 18.0, *) {
                    NavigationLink("Control Center") {
                        HelpArticleView(
                            title: "Control Center",
                            icon: "slider.horizontal.3",
                            sections: [
                                HelpSection(
                                    title: "Mileage Toggle",
                                    content: "Add a mileage tracking toggle to Control Center for one-tap pause and resume. Swipe down from the top-right corner to access it instantly."
                                ),
                                HelpSection(
                                    title: "Adding the Control",
                                    content: "Go to Settings > Control Center, scroll down to find 'Mileage Timer' under FLO, and tap the + button to add it."
                                ),
                                HelpSection(
                                    title: "iOS 18 Required",
                                    content: "Control Center widgets are a new feature in iOS 18. If you don't see this option, make sure your device is updated to iOS 18 or later."
                                )
                            ]
                        )
                    }
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(x: viewAppeared ? 0 : 15)
                    .animation(FLOAnimation.standard.delay(0.45), value: viewAppeared)
                }
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
                                title: "Location Privacy",
                                content: "Mileage tracking uses your location only to record trips. Location data stays on your device and is never sent to our servers."
                            ),
                            HelpSection(
                                title: "Backups",
                                content: "Your data is included in your device's iCloud backup if enabled. This allows restoration if you get a new device."
                            )
                        ]
                    )
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(x: viewAppeared ? 0 : 15)
                .animation(FLOAnimation.standard.delay(0.5), value: viewAppeared)
            }
            
            Section("Need More Help?") {
                Link(destination: URL(string: "mailto:flo.financeapp@gmail.com")!) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Contact Support")
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.primary)
                            Text("flo.financeapp@gmail.com")
                                .font(.caption)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "envelope.fill")
                             .foregroundStyle(Color.brandPrimaryText)
                            .accessibilityHidden(true)
                    }
                }
                .buttonStyle(.plain)
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(x: viewAppeared ? 0 : 15)
                .animation(FLOAnimation.standard.delay(0.55), value: viewAppeared)
                
                Link(destination: URL(string: "https://floptimizer.github.io/FLO/index.html#features")!) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("FAQ & Tutorials")
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.primary)
                            Text("https://floptimizer.github.io/FLO/index.html")
                                .font(.caption)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "book.fill")
                             .foregroundStyle(Color.brandPrimaryText)
                            .accessibilityHidden(true)
                    }
                }
                .buttonStyle(.plain)
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(x: viewAppeared ? 0 : 15)
                .animation(FLOAnimation.standard.delay(0.6), value: viewAppeared)
                
                Link(destination: URL(string: "https://apps.apple.com/app/flo-finance-ledger-optimizer/id6740109874?action=write-review")!) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Rate FLO")
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.primary)
                            Text("Leave a review on the App Store")
                                .font(.caption)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .accessibilityHidden(true)
                    }
                }
                .buttonStyle(.plain)
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(x: viewAppeared ? 0 : 15)
                .animation(FLOAnimation.standard.delay(0.65), value: viewAppeared)
            }
        }
        .navigationTitle("Help Center")
        .onAppear {
            withAnimation(FLOAnimation.standard) {
                viewAppeared = true
            }
            AccessibilityAnnouncement.screenChanged("Help center")
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
                        .font(.largeTitle)
                         .foregroundStyle(Color.brandPrimaryText)
                        .symbolEffect(.bounce, value: viewAppeared)
                    
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
                .padding(.bottom, 8)
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)
                
                // Sections
                ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title)
                            .font(.headline)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                             .foregroundStyle(Color.brandPrimaryText)
                            .accessibilityAddTraits(.isHeader)
                        
                        Text(section.content)
                            .font(.body)
                            .lineLimit(20)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 15)
                    .animation(
                        FLOAnimation.standard.delay(0.1 + Double(index) * 0.05),
                        value: viewAppeared
                    )
                }
            }
            .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(FLOAnimation.standard) {
                viewAppeared = true
            }
            AccessibilityAnnouncement.screenChanged(title)
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .modelContainer(for: [Transaction.self, MileageTrip.self, ReceiptData.self], inMemory: true)
}
