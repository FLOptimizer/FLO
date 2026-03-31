//  SettingsView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 5.0 - Build 10: Alphabetized sections
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v5.0 - Build 10:
//  ✅ REORDERED: All sections alphabetized (About, Categories, Data, Features, Preferences, Premium, Profile, Security, Support)
//  ✅ REORDERED: Items within Preferences alphabetized (Appearance, Data & Storage, Notifications)
//  ✅ REORDERED: Items within Support alphabetized (Contact, EULA, Help, Privacy, Tax, Terms)
//  ✅ REORDERED: Items within Profile alphabetized (Business Profile, Edit Profile)
//  ✅ REORDERED: Items within Data alphabetized (Backup, Export, Receipt Storage)
//
//  CHANGES v4.1:
//  ✅ FIXED: Removed redundant Cancel button from ProfileEditView toolbar
//  ✅ RATIONALE: View is pushed via NavigationLink, system back button handles dismissal
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
import AuthenticationServices

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("userName") private var userName = ""
    @AppStorage("userEmail") private var userEmail = ""
    @AppStorage("preferredColorScheme") private var preferredColorScheme = "system"
    @AppStorage("hideBalancesOnDashboard") private var hideBalancesOnDashboard = true
    
    @State private var showingAbout = false
    @State private var showingExportOptions = false
    @State private var showingSignOutAlert = false
    @State private var showingDeleteAccountAlert = false
    @State private var viewAppeared = false

    @ObservedObject private var appleAuth = AppleAuthService.shared
    @StateObject private var signInCoordinator = AppleSignInCoordinator()
    
    private var colorScheme: ColorScheme? {
        switch preferredColorScheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
    
    var body: some View {
        NavigationStack {
            // Build 10.1: Priority-ordered sections (Profile, Security, Premium, Preferences, Categories, Features, Data, Support, About)
            Form {
                // 1. Profile Section — identity first
                Section {
                    // Profile header with branded avatar
                    HStack(spacing: 14) {
                        ZStack(alignment: .bottomTrailing) {
                            // Avatar circle with initials or icon
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.brandPrimary, Color.brandPrimary.opacity(0.7)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 52, height: 52)

                                if userName.isEmpty {
                                    Image(systemName: "person.fill")
                                        .font(.title2)
                                        .foregroundStyle(.white)
                                } else {
                                    Text(initials(from: userName))
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                }
                            }

                            if appleAuth.isSignedIn {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.incomeGreen)
                                    .background(Circle().fill(Color.floSurface).frame(width: 18, height: 18))
                                    .offset(x: 2, y: 2)
                            }
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            if userName.isEmpty {
                                Text(appleAuth.isSignedIn ? "Apple User" : "Sign In to Get Started")
                                    .font(.headline)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .foregroundStyle(appleAuth.isSignedIn ? .primary : .secondary)
                            } else {
                                Text(userName)
                                    .font(.title3.weight(.semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .foregroundStyle(.primary)
                            }

                            if !userEmail.isEmpty {
                                Text(userEmail)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    .foregroundStyle(.secondary)
                            } else if !appleAuth.isSignedIn {
                                Text("Connect your Apple Account for cross-device sync")
                                    .font(.caption)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.7)
                                    .foregroundStyle(.secondary)
                            }

                            if appleAuth.isSignedIn {
                                HStack(spacing: 4) {
                                    Image(systemName: "apple.logo")
                                        .font(.caption2)
                                    Text("Verified")
                                        .font(.caption2.weight(.medium))
                                }
                                .foregroundStyle(Color.incomeGreen)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 6)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel({
                        var label = userName.isEmpty ? "No name set" : userName
                        if !userEmail.isEmpty { label += ", \(userEmail)" }
                        if appleAuth.isSignedIn { label += ", verified with Apple" }
                        return label
                    }())

                    // Sign In with Apple button (when not signed in)
                    if !appleAuth.isSignedIn {
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            switch result {
                            case .success(let authorization):
                                HapticService.play(.success)
                                appleAuth.handleAuthorization(authorization)
                            case .failure(let error):
                                HapticService.play(.error)
                                #if DEBUG
                                print("[AppleAuth] Sign in failed: \(error.localizedDescription)")
                                #endif
                            }
                        }
                        .signInWithAppleButtonStyle(.whiteOutline)
                        .frame(height: 44)
                        .cornerRadius(8)
                    }

                    settingsDetailRow(
                        icon: "person.text.rectangle",
                        title: "Account Details",
                        destination: .settingsEditProfile
                    )

                    settingsDetailRow(
                        icon: "building.2",
                        title: "Business Profile",
                        destination: .settingsBusinessProfile
                    )
                } header: {
                    Text("Profile")
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)

                // 2. Security & Privacy — protect the account
                Section {
                    Button {
                        NavigationService.shared.selectedDetail = .settingsSecurity
                    } label: {
                        HStack {
                            Image(systemName: "lock.shield.fill")
                                 .foregroundStyle(Color.brandPrimary)
                                .accessibilityHidden(true)

                            Text("Passcode & Biometrics")
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)

                            Spacer()

                            if BiometricAuthService.shared.biometricEnabled || PasscodeService.shared.hasPasscode() {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.incomeGreen)
                                    .accessibilityHidden(true)
                            }

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Passcode and Biometrics\(BiometricAuthService.shared.biometricEnabled || PasscodeService.shared.hasPasscode() ? ", enabled" : ", not configured")")
                    .accessibilityHint("Opens security settings")

                    Toggle(isOn: $hideBalancesOnDashboard) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Hide Balances")
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Text("Blur balances on dashboard until tapped")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.7)
                            }
                        } icon: {
                            Image(systemName: hideBalancesOnDashboard ? "eye.slash.fill" : "eye.fill")
                                .foregroundStyle(Color.brandPrimary)
                                .accessibilityHidden(true)
                        }
                    }
                    .tint(Color.brandPrimary)
                    .onChange(of: hideBalancesOnDashboard) { _, _ in
                        HapticService.play(.light)
                    }
                    .accessibilityLabel("Hide balances on dashboard")
                    .accessibilityValue(hideBalancesOnDashboard ? "Enabled" : "Disabled")
                } header: {
                    Text("Security & Privacy")
                } footer: {
                    Text("Protect your financial data with Face ID, passcode, or hidden balances")
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)

                // 3. Premium Features — subscription status
                Section {
                    settingsDetailRow(
                        icon: "star.fill",
                        title: "Subscription",
                        trailing: SubscriptionManager.shared.currentTier.displayName,
                        destination: .settingsSubscription
                    )
                    .accessibilityLabel("Subscription, current plan: \(SubscriptionManager.shared.currentTier.displayName)")
                } header: {
                    Text("Premium Features")
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)

                // 4. Preferences — daily customization
                Section {
                    settingsDetailRow(
                        icon: "paintbrush.fill",
                        title: "Appearance",
                        trailing: ColorSchemeManager.shared.currentScheme.emoji,
                        destination: .settingsAppearance
                    )
                    .accessibilityLabel("Appearance, current: \(ColorSchemeManager.shared.currentScheme.name)")

                    settingsDetailRow(
                        icon: "externaldrive.fill",
                        title: "Data & Storage",
                        destination: .settingsDataStorage
                    )

                    settingsDetailRow(
                        icon: "bell.fill",
                        title: "Notifications",
                        destination: .settingsNotifications
                    )
                } header: {
                    Text("Preferences")
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)

                // 5. Categories — periodic task
                Section("Categories") {
                    settingsDetailRow(
                        icon: "folder",
                        title: "Manage Categories",
                        destination: .settingsCategories
                    )
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(FLOAnimation.standard.delay(0.25), value: viewAppeared)

                // 6. Data — infrequent but important
                Section {
                    settingsDetailRow(
                        icon: "icloud.fill",
                        title: "Backup & Sync",
                        destination: .settingsBackup
                    )

                    Button {
                        HapticService.play(.medium)
                        showingExportOptions = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                 .foregroundStyle(Color.brandPrimary)
                                .accessibilityHidden(true)
                            Text("Export Data")
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)

                    settingsDetailRow(
                        icon: "doc.text.image",
                        title: "Receipt Storage",
                        subtitle: "Export & manage receipt images",
                        destination: .settingsReceiptStorage
                    )
                } header: {
                    Text("Data")
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(FLOAnimation.standard.delay(0.35), value: viewAppeared)

                // 8. Support — only when needed
                Section {
                    Link(destination: URL(string: "mailto:flowledgerco@gmail.com")!) {
                        Label {
                            Text("Contact Support")
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "envelope.fill")
                                 .foregroundStyle(Color.brandPrimary)
                                .accessibilityHidden(true)
                        }
                    }
                    .buttonStyle(.plain)

                    settingsDetailRow(
                        icon: "signature",
                        title: "End User License Agreement",
                        destination: .settingsEULA
                    )

                    settingsDetailRow(
                        icon: "questionmark.circle.fill",
                        title: "Help Center",
                        destination: .settingsHelpCenter
                    )

                    settingsDetailRow(
                        icon: "hand.raised.fill",
                        title: "Privacy Policy",
                        destination: .settingsPrivacyPolicy
                    )

                    settingsDetailRow(
                        icon: "exclamationmark.triangle.fill",
                        title: "Tax & Legal Disclaimer",
                        destination: .settingsTaxDisclaimer
                    )

                    settingsDetailRow(
                        icon: "doc.text.fill",
                        title: "Terms of Service",
                        destination: .settingsTermsOfService
                    )
                    // Account deletion (required by App Store when using Sign In with Apple)
                    if appleAuth.isSignedIn {
                        Button(role: .destructive) {
                            HapticService.play(.heavy)
                            showingDeleteAccountAlert = true
                        } label: {
                            Label {
                                Text("Delete Account")
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            } icon: {
                                Image(systemName: "person.crop.circle.badge.minus")
                                    .foregroundStyle(Color.expenseRed)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                } header: {
                    Text("Support")
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(FLOAnimation.standard.delay(0.4), value: viewAppeared)

                // 9. About — last, almost never needed
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
                                     .foregroundStyle(Color.brandPrimary)
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
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .navigationTitle("Settings")
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .sheet(isPresented: $showingExportOptions) {
                ExportOptionsView()
            }
            .alert("Sign Out?", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) {
                    HapticService.play(.light)
                }
                Button("Sign Out", role: .destructive) {
                    AppleAuthService.shared.signOut()
                    HapticService.play(.success)
                }
            } message: {
                Text("Your data will remain on this device. You can sign in again anytime to restore cross-device sync.")
            }
            .alert("Delete Account?", isPresented: $showingDeleteAccountAlert) {
                Button("Cancel", role: .cancel) {
                    HapticService.play(.light)
                }
                Button("Delete Account", role: .destructive) {
                    Task {
                        await AppleAuthService.shared.deleteAccount()
                        HapticService.play(.success)
                    }
                }
            } message: {
                Text("This will remove your Apple ID connection and clear your profile information. Your financial data will remain on this device. This action cannot be undone.")
            }
            .onAppear {
                DispatchQueue.main.async {
                    withAnimation(FLOAnimation.standard) {
                        viewAppeared = true
                    }
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

    /// Extract up to 2 initials from a name (e.g. "Travis A" → "TA")
    // MARK: - Settings Detail Row Helper

    /// Creates a tappable row that sets NavigationService.selectedDetail.
    /// Uses Button with .borderless style which works reliably in macOS Form/List.
    private func settingsDetailRow(
        icon: String,
        title: String,
        subtitle: String? = nil,
        trailing: String? = nil,
        destination: NavigationDestination
    ) -> some View {
        Button {
            NavigationService.shared.selectedDetail = destination
        } label: {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(Color.brandPrimary)
                    .accessibilityHidden(true)
                if let subtitle {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                } else {
                    Text(title)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer()
                if let trailing {
                    Text(trailing)
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
        }
        .buttonStyle(.plain)
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        let firstInitial = parts.first?.prefix(1) ?? ""
        let lastInitial = parts.count > 1 ? parts.last!.prefix(1) : ""
        return "\(firstInitial)\(lastInitial)".uppercased()
    }
}

// MARK: - Profile Edit View

/// Account Details — shows Apple Account info, personal profile editing, and Sign Out.
/// Replaces the old ProfileEditView + standalone Sign Out button.
struct AccountDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var appleAuth = AppleAuthService.shared
    @Binding var userName: String
    @Binding var userEmail: String
    @Binding var showingSignOutAlert: Bool

    @State private var editedName: String
    @State private var editedEmail: String
    @State private var viewAppeared = false

    init(userName: Binding<String>, userEmail: Binding<String>, showingSignOutAlert: Binding<Bool>) {
        self._userName = userName
        self._userEmail = userEmail
        self._showingSignOutAlert = showingSignOutAlert
        self._editedName = State(initialValue: userName.wrappedValue)
        self._editedEmail = State(initialValue: userEmail.wrappedValue)
    }

    private var initials: String {
        let parts = editedName.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.count > 1 ? parts.last!.prefix(1) : ""
        return "\(first)\(last)".uppercased()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                ProfileHeaderCard(
                    icon: editedName.isEmpty ? "person.fill" : initials,
                    title: "Account Details",
                    subtitle: appleAuth.isSignedIn
                        ? "Connected with Apple Account"
                        : "Your personal profile",
                    color: .brandPrimary,
                    isInitials: !editedName.isEmpty
                )

                // Apple Account Status
                if appleAuth.isSignedIn {
                    ProfileSectionCard(title: "Apple Account") {
                        ProfileDisplayRow(
                            label: "Status",
                            value: "Verified",
                            icon: "checkmark.seal.fill"
                        )

                        if !userEmail.isEmpty {
                            ProfileDisplayRow(
                                label: "Apple Email",
                                value: userEmail,
                                icon: "envelope.fill"
                            )
                        }
                    }
                }

                // Personal Information (editable)
                ProfileSectionCard(title: "Personal Information") {
                    ProfileFieldRow(
                        label: "Display Name",
                        placeholder: "Your Name",
                        text: $editedName,
                        isValid: editedName.isEmpty ? nil : true
                    )

                    if !appleAuth.isSignedIn {
                        ProfileFieldRow(
                            label: "Email",
                            placeholder: "email@example.com",
                            text: $editedEmail,
                            isValid: editedEmail.isEmpty ? nil : editedEmail.contains("@"),
                            capitalize: false
                        )
                    }
                }

                // Privacy note
                ProfileFooterNote(
                    icon: "lock.shield.fill",
                    text: "Your profile is stored locally on your device and is never shared with third parties."
                )

                // Sign Out — placed at the bottom, clearly separated
                if appleAuth.isSignedIn {
                    VStack(spacing: 8) {
                        Divider()
                            .padding(.vertical, 8)

                        Button(role: .destructive) {
                            HapticService.play(.heavy)
                            showingSignOutAlert = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Sign Out")
                                    .fontWeight(.medium)
                            }
                            .foregroundStyle(Color.expenseRed)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.expenseRed.opacity(0.08))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)

                        Text("Signing out will disconnect your Apple Account from this device.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(16)
            .opacity(viewAppeared ? 1 : 0.001)
        }
        .navigationTitle("Account Details")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    HapticService.play(.medium)
                    saveProfile()
                } label: {
                    Text("Save")
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                withAnimation(FLOAnimation.standard) {
                    viewAppeared = true
                }
            }
            AccessibilityAnnouncement.screenChanged("Account details")
        }
    }

    private func saveProfile() {
        userName = editedName
        if !appleAuth.isSignedIn {
            userEmail = editedEmail
        }
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
    @AppStorage("plaidSyncNotificationsEnabled") private var plaidSyncEnabled = true
    @AppStorage("plaidErrorNotificationsEnabled") private var plaidErrorEnabled = true

    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    @State private var viewAppeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ProfileHeaderCard(
                    icon: "bell.fill",
                    title: "Notifications",
                    subtitle: "Manage your reminders and alerts",
                    color: .brandPrimary
                )

                ProfileSectionCard(title: "General") {
                    ProfileToggleRow(
                        icon: "bell.badge",
                        label: "Enable Notifications",
                        isOn: $notificationsEnabled,
                        subtitle: "Allow FLO to send you important reminders and updates"
                    )
                    .onChange(of: notificationsEnabled) { _, _ in
                        HapticService.play(.light)
                    }
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)

                if notificationsEnabled {
                    ProfileSectionCard(title: "Reminders") {
                        ProfileToggleRow(
                            icon: "calendar.badge.exclamationmark",
                            label: "Quarterly Tax Deadlines",
                            isOn: $taxReminderEnabled
                        )
                        .onChange(of: taxReminderEnabled) { _, _ in
                            HapticService.play(.light)
                        }

                        ProfileToggleRow(
                            icon: "exclamationmark.triangle",
                            label: "Budget Alerts",
                            isOn: $budgetAlertEnabled
                        )
                        .onChange(of: budgetAlertEnabled) { _, _ in
                            HapticService.play(.light)
                        }

                        ProfileToggleRow(
                            icon: "chart.bar.doc.horizontal",
                            label: "Weekly Summary",
                            isOn: $weeklyReportEnabled
                        )
                        .onChange(of: weeklyReportEnabled) { _, _ in
                            HapticService.play(.light)
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))

                    // Bank Sync section — only for Pro subscribers with Plaid
                    if subscriptionManager.currentTier == .pro {
                        ProfileSectionCard(title: "Bank Sync") {
                            ProfileToggleRow(
                                icon: "arrow.triangle.2.circlepath",
                                label: "Transaction Updates",
                                isOn: $plaidSyncEnabled
                            )
                            .onChange(of: plaidSyncEnabled) { _, _ in
                                HapticService.play(.light)
                            }

                            ProfileToggleRow(
                                icon: "exclamationmark.shield",
                                label: "Connection Alerts",
                                isOn: $plaidErrorEnabled
                            )
                            .onChange(of: plaidErrorEnabled) { _, _ in
                                HapticService.play(.light)
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        ))

                        ProfileFooterNote(
                            icon: "info.circle",
                            text: "Get notified when new transactions sync or if your bank connection needs attention"
                        )
                    }
                }
            }
            .padding(16)
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

    @State private var transactions: [Transaction] = []
    @State private var trips: [MileageTrip] = []
    @State private var receipts: [ReceiptData] = []

    @State private var showingClearDataAlert = false
    @State private var viewAppeared = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ProfileHeaderCard(
                    icon: "externaldrive.fill",
                    title: "Data & Storage",
                    subtitle: "Manage your app data and storage",
                    color: .brandPrimary
                )

                // Storage counts
                ProfileSectionCard(title: "Storage") {
                    ProfileInfoRow(icon: "creditcard", label: "Transactions", value: "\(transactions.count)")
                    ProfileInfoRow(icon: "car", label: "Mileage Trips", value: "\(trips.count)")
                    ProfileInfoRow(icon: "doc.text.image", label: "Receipts", value: "\(receipts.count)")
                }

                // Receipt storage management
                ProfileSectionCard(title: "Management") {
                    NavigationLink {
                        ReceiptStorageSettingsView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.body)
                                .foregroundStyle(Color.brandPrimary)
                                .frame(width: 24, alignment: .center)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Manage Receipt Storage")
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text("Export to ZIP, purge by month/year")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }

                // Danger zone
                ProfileSectionCard(title: "Danger Zone") {
                    ProfileActionRow(
                        icon: "trash",
                        label: "Clear All Data",
                        style: .destructive
                    ) {
                        HapticService.play(.heavy)
                        showingClearDataAlert = true
                    }
                }

                ProfileFooterNote(
                    icon: "exclamationmark.triangle.fill",
                    text: "Clearing data will permanently delete all transactions, trips, receipts, and settings. This action cannot be undone."
                )
            }
            .padding(16)
            .opacity(viewAppeared ? 1 : 0.001)
        }
        .navigationTitle("Data & Storage")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
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
        .task { loadData() }
        .onAppear {
            DispatchQueue.main.async {
                withAnimation(FLOAnimation.standard) {
                    viewAppeared = true
                }
            }
            AccessibilityAnnouncement.screenChanged("Data and storage")
        }
        .onDisappear {
            transactions = []
            trips = []
            receipts = []
        }
    }

    private func loadData() {
        transactions = (try? modelContext.fetch(FetchDescriptor<Transaction>())) ?? []
        trips = (try? modelContext.fetch(FetchDescriptor<MileageTrip>())) ?? []
        receipts = (try? modelContext.fetch(FetchDescriptor<ReceiptData>())) ?? []
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

/// Backup & Sync settings — now powered by CloudSyncDetailsView.
/// CloudSyncDetailsView provides full iCloud sync management:
/// - Sync enable/disable toggle
/// - Account status & network display
/// - Sync progress indicator
/// - Error display with recovery suggestions
/// - Manual sync refresh / reset buttons
struct BackupSettingsView: View {
    var body: some View {
        CloudSyncDetailsView()
            .onAppear {
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
                             .foregroundStyle(Color.brandPrimary)
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
                             .foregroundStyle(Color.brandPrimary)
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
                         .foregroundStyle(Color.brandPrimary)
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
                             .foregroundStyle(Color.brandPrimary)
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
                    .background(Color.floSecondarySystemBackground)
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
