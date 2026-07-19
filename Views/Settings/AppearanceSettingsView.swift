//  AppearanceSettingsView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.6 - Added Celebrations toggle for success animations
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.6:
//  ✅ ADDED: Celebrations toggle in new "Feedback" section
//  ✅ ADDED: celebrationsEnabled @AppStorage preference
//  ✅ ADDED: Accessible toggle with hint about confetti animations
//
//  CHANGES v1.5 - Dynamic Type Verification:
//  ✅ FIXED: Color scheme title text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Color scheme current value text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Color scheme emoji missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Toggle labels ("Show Cents in Lists", "Compact List View") missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Toggle descriptions missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Section footer text missing lineLimit + minimumScaleFactor
//
//  CHANGES v1.4:
//  ✅ Screen change announcement on appear
//  ✅ Color scheme row: emoji hidden, spoken scheme name
//
//  CHANGES FROM v1.2:
//  ✅ Haptic feedback on theme selection
//  ✅ Haptic on toggle changes
//  ✅ Section entrance animations
//  ✅ Color scheme preview animation
//
//  PREVIOUS (v1.2):
//  - Working theme picker, adaptive colors

import SwiftUI
import FLODesignSystem

struct AppearanceSettingsView: View {
    @AppStorage("preferredColorScheme") private var preferredColorScheme = "system"
    @AppStorage("showCentsInList") private var showCentsInList = true
    @AppStorage("compactListView") private var compactListView = false
    @AppStorage("celebrationsEnabled") private var celebrationsEnabled = true
    @State private var colorSchemeManager = ColorSchemeManager.shared
    @State private var viewAppeared = false
    
    // Haptic Generators
            
    private var colorScheme: ColorScheme? {
        switch preferredColorScheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ProfileHeaderCard(
                    icon: "paintbrush.fill",
                    title: "Appearance",
                    subtitle: "Customize how FLO looks and feels",
                    color: .brandPrimary
                )

                // Color Scheme Section
                ProfileSectionCard(title: "Colors") {
                    ProfileNavigationRow(
                        icon: "paintpalette.fill",
                        label: "Color Scheme",
                        value: colorSchemeManager.currentScheme.name,
                        iconColor: .brandPrimary
                    ) {
                        ColorSchemeSettingsView()
                    }
                    .accessibilityLabel("Color scheme, current: \(colorSchemeManager.currentScheme.name)")
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)

                // Theme Section
                ProfileSectionCard(title: "Light/Dark Mode") {
                    Picker("App Theme", selection: $preferredColorScheme) {
                        Label {
                            Text("System")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "circle.lefthalf.filled")
                                .accessibilityHidden(true)
                                .foregroundStyle(Color.brandPrimary)
                        }
                        .tag("system")

                        Label {
                            Text("Light")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "sun.max.fill")
                                .accessibilityHidden(true)
                                .foregroundStyle(Color.brandPrimary)
                        }
                        .tag("light")

                        Label {
                            Text("Dark")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "moon.fill")
                                .accessibilityHidden(true)
                                .foregroundStyle(Color.brandPrimary)
                        }
                        .tag("dark")
                    }
                    .pickerStyle(.inline)
                    .padding(.horizontal, 16)
                    .onChange(of: preferredColorScheme) { _, _ in
                        HapticService.play(.selection)
                    }
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)

                // Display Options Section
                ProfileSectionCard(title: "Display Options") {
                    ProfileToggleRow(
                        icon: "dollarsign.circle",
                        label: "Show Cents in Lists",
                        isOn: $showCentsInList,
                        subtitle: "Display $1,234.56 instead of $1,235"
                    )
                    .onChange(of: showCentsInList) { _, _ in
                        HapticService.play(.light)
                    }

                    ProfileToggleRow(
                        icon: "rectangle.compress.vertical",
                        label: "Compact List View",
                        isOn: $compactListView,
                        subtitle: "Reduce spacing between items"
                    )
                    .onChange(of: compactListView) { _, _ in
                        HapticService.play(.light)
                    }
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)

                // Feedback Section
                ProfileSectionCard(title: "Feedback") {
                    ProfileToggleRow(
                        icon: "party.popper.fill",
                        label: "Success Celebrations",
                        isOn: $celebrationsEnabled,
                        subtitle: "Show confetti and animations for achievements"
                    )
                    .onChange(of: celebrationsEnabled) { _, newValue in
                        if newValue {
                            // Play celebration haptic as preview
                            HapticService.shared.celebration()
                        } else {
                            HapticService.play(.light)
                        }
                    }
                    .accessibilityLabel("Success Celebrations")
                    .accessibilityValue(celebrationsEnabled ? "On" : "Off")
                    .accessibilityHint("When enabled, shows confetti and animations when you mark invoices as paid or add income")

                    ProfileInfoRow(
                        icon: "info.circle",
                        label: "Celebrations",
                        value: "Invoices, income, goals"
                    )
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)
            }
            .padding(16)
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(colorScheme)
        .onAppear {
            withAnimation(FLOAnimation.standard) {
                viewAppeared = true
            }
            AccessibilityAnnouncement.screenChanged("Appearance")
        }
    }
    
    // MARK: - Haptic Preparation
    
    }

// MARK: - Preview

#Preview {
    NavigationStack {
        AppearanceSettingsView()
    }
}
