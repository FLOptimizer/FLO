//  BudgetSettingsView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.6 - Catalyst picker style · VoiceOver Audit
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.5 - VoiceOver Audit:
//  ✅ VERIFIED: Exclamation triangle icon in notifications warning already hidden
//  ✅ VERIFIED: Folder gear icon in "coming soon" already hidden
//  ✅ VERIFIED: Slider accessibility value provides spoken threshold
//  ✅ VERIFIED: Screen change announcement present
//  ✅ VERIFIED: Form Labels auto-handled by SwiftUI
//
//  CHANGES v1.4 - Dynamic Type verification:
//
//  CHANGES v1.3:
//  ✅ Screen change announcements
//  ✅ Warning threshold slider accessibility value
//  ✅ Notification warning row combined
//  ✅ Coming soon decorative icon hidden
//
//  CHANGES v1.2:
//  ✅ Haptic feedback on toggle changes
//  ✅ Haptic on slider changes
//  ✅ Section entrance animations
//  ✅ Notification warning animation
//  ✅ Threshold value animation
//
//  PREVIOUS (v1.1):
//  - Notification permission request on toggle

import SwiftUI
import FLODesignSystem
import UserNotifications

struct BudgetSettingsView: View {
    @AppStorage("defaultBudgetType") private var defaultBudgetType = "envelope"
    @AppStorage("enableMonthlyRollover") private var enableRollover = true
    @AppStorage("showBudgetWarnings") private var showWarnings = true
    @AppStorage("warningThresholdPercent") private var warningThreshold = 80.0
    
    @State private var notificationsAuthorized = false
    @State private var showingNotificationDeniedAlert = false
    @State private var viewAppeared = false
    
    // Haptic Generators
            
    var body: some View {
        List {
            Section {
                Picker("Default Budget Type", selection: $defaultBudgetType) {
                    ForEach(BudgetType.allCases, id: \.rawValue) { type in
                        Label(type.displayName, systemImage: type.systemImageName)
                            .tag(type.rawValue)
                    }
                }
                #if os(macOS) || targetEnvironment(macCatalyst)
                .pickerStyle(.menu)
                #else
                .pickerStyle(.navigationLink)
                #endif
                .onChange(of: defaultBudgetType) { _, _ in
                    HapticService.play(.selection)
                }
            } header: {
                Text("Defaults")
            } footer: {
                if let type = BudgetType(rawValue: defaultBudgetType) {
                    Text(type.shortDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .opacity(viewAppeared ? 1 : 0.001)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)

            Section {
                Toggle("Enable Monthly Rollover", isOn: $enableRollover)
                    .onChange(of: enableRollover) { _, _ in
                        HapticService.play(.light)
                    }
            } header: {
                Text("Envelope Budgeting")
            } footer: {
                Text("Unused funds automatically carry over to the next month")
            }
            .opacity(viewAppeared ? 1 : 0.001)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)

            Section {
                Toggle("Show Budget Warnings", isOn: Binding(
                    get: { showWarnings },
                    set: { newValue in
                        if newValue {
                            HapticService.play(.medium)
                            requestNotificationPermission()
                        } else {
                            HapticService.play(.light)
                            showWarnings = false
                        }
                    }
                ))

                if showWarnings {
                    if !notificationsAuthorized {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .accessibilityHidden(true)
                                .foregroundStyle(.orange)
                                .symbolEffect(.pulse, value: viewAppeared)
                            Text("Notifications disabled in Settings")
                                .font(.caption)
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
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Warning Threshold")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack {
                            Slider(value: $warningThreshold, in: 50...100, step: 5)
                                .tint(.orange)
                                .onChange(of: warningThreshold) { _, _ in
                                    HapticService.play(.selection)
                                }
                                .accessibilityValue("\(Int(warningThreshold)) percent")

                            Text("\(Int(warningThreshold))%")
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 60)
                                .foregroundStyle(.secondary)
                                .contentTransition(.numericText())
                        }
                    }
                    .padding(.top, 8)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            } header: {
                Text("Notifications")
            } footer: {
                Text("Get notified when you reach ")
                + Text("\(Int(warningThreshold))%").bold()
                + Text(" of your budget")
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showWarnings)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: notificationsAuthorized)
            .opacity(viewAppeared ? 1 : 0.001)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)

            Section {
                NavigationLink {
                    BudgetCategoryDefaultsView()
                } label: {
                    Label("Category Budget Defaults", systemImage: "folder")
                }
            } header: {
                Text("Advanced")
            }
            .opacity(viewAppeared ? 1 : 0.001)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Budget Preferences")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
                        checkNotificationStatus()
            withAnimation(FLOAnimation.standard) {
                viewAppeared = true
            }
            AccessibilityAnnouncement.screenChanged("Budget preferences")
        }
        .alert("Notifications Required", isPresented: $showingNotificationDeniedAlert) {
            Button("Open Settings") {
                HapticService.play(.medium)
                openNotificationSettings()
            }
            Button("Cancel", role: .cancel) {
                HapticService.play(.light)
                showWarnings = false
            }
        } message: {
            Text("Budget warnings require notification permissions. Please enable notifications in Settings.")
        }
    }
    
    // MARK: - Haptic Preparation
    
        
    // MARK: - Notification Helpers
    
    private func requestNotificationPermission() {
        NotificationPermissionHelper.requestWithExplanation(context: .budgetAlerts) { granted in
            DispatchQueue.main.async {
                notificationsAuthorized = granted
                showWarnings = granted
                
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

struct BudgetCategoryDefaultsView: View {
    @State private var viewAppeared = false
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "folder.badge.gearshape")
                        .accessibilityHidden(true)
                        .font(.largeTitle)
                        .foregroundStyle(Color.brandPrimary)
                        .symbolEffect(.bounce, value: viewAppeared)
                        .accessibilityHidden(true)
                    
                    Text("Set default budget amounts per category")
                        .foregroundStyle(.secondary)
                    Text("Coming soon in a future update")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Category Defaults")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewAppeared = true
        }
    }
}

#Preview {
    NavigationStack {
        BudgetSettingsView()
    }
}
