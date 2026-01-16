//  AppearanceSettingsView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.3 - Enhanced haptics and micro-animations
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
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
                                .foregroundStyle(.primary)
                            Text(colorSchemeManager.currentScheme.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(colorSchemeManager.currentScheme.emoji)
                            .font(.title3)
                    }
                }
            } header: {
                Text("Colors")
            } footer: {
                Text("Choose a color scheme that matches your style")
            }
            .opacity(viewAppeared ? 1 : 0)
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
                            .foregroundStyle(Color.brandPrimary)
                    }
                    .tag("system")
                    
                    Label {
                        Text("Light")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "sun.max.fill")
                            .foregroundStyle(Color.brandPrimary)
                    }
                    .tag("light")
                    
                    Label {
                        Text("Dark")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "moon.fill")
                            .foregroundStyle(Color.brandPrimary)
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
            }
            .opacity(viewAppeared ? 1 : 0)
            .offset(y: viewAppeared ? 0 : 10)
            .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
            
            // Display Options Section
            Section {
                Toggle(isOn: $showCentsInList) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Show Cents in Lists")
                            .foregroundStyle(.primary)
                        Text("Display $1,234.56 instead of $1,235")
                            .font(.caption)
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
                            .foregroundStyle(.primary)
                        Text("Reduce spacing between items")
                            .font(.caption)
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
            }
            .opacity(viewAppeared ? 1 : 0)
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
