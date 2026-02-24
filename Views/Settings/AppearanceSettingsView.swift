//  AppearanceSettingsView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.5 - Dynamic Type verification: lineLimit + minimumScaleFactor on all text
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
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

struct AppearanceSettingsView: View {
    @AppStorage("preferredColorScheme") private var preferredColorScheme = "system"
    @AppStorage("showCentsInList") private var showCentsInList = true
    @AppStorage("compactListView") private var compactListView = false
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
        Form {
            // Color Scheme Section
            Section {
                NavigationLink {
                    ColorSchemeSettingsView()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Color Scheme")
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.primary)
                            Text(colorSchemeManager.currentScheme.name)
                                .font(.caption)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(colorSchemeManager.currentScheme.emoji)
                            .font(.title3)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityLabel("Color scheme, current: \(colorSchemeManager.currentScheme.name)")
            } header: {
                Text("Colors")
            } footer: {
                Text("Choose a color scheme that matches your style")
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            .opacity(viewAppeared ? 1 : 0.001)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)
            
            // Theme Section
            Section {
                Picker("App Theme", selection: $preferredColorScheme) {
                    Label {
                        Text("System")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "circle.lefthalf.filled")
                            .accessibilityHidden(true)
                             .foregroundStyle(Color.brandPrimaryText)
                    }
                    .tag("system")
                    
                    Label {
                        Text("Light")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "sun.max.fill")
                            .accessibilityHidden(true)
                             .foregroundStyle(Color.brandPrimaryText)
                    }
                    .tag("light")
                    
                    Label {
                        Text("Dark")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "moon.fill")
                            .accessibilityHidden(true)
                             .foregroundStyle(Color.brandPrimaryText)
                    }
                    .tag("dark")
                }
                .pickerStyle(.inline)
                .onChange(of: preferredColorScheme) { _, _ in
                    HapticService.play(.selection)
                }
            } header: {
                Text("Light/Dark Mode")
            } footer: {
                Text("Choose how FLO appears throughout the day")
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            .opacity(viewAppeared ? 1 : 0.001)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
            
            // Display Options Section
            Section {
                Toggle(isOn: $showCentsInList) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Show Cents in Lists")
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.primary)
                        Text("Display $1,234.56 instead of $1,235")
                            .font(.caption)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(Color.brandPrimary)
                .onChange(of: showCentsInList) { _, _ in
                    HapticService.play(.light)
                }
                
                Toggle(isOn: $compactListView) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Compact List View")
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.primary)
                        Text("Reduce spacing between items")
                            .font(.caption)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(Color.brandPrimary)
                .onChange(of: compactListView) { _, _ in
                    HapticService.play(.light)
                }
            } header: {
                Text("Display Options")
            } footer: {
                Text("Customize how transactions and amounts are displayed")
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            .opacity(viewAppeared ? 1 : 0.001)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)
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
