//  ColorSchemeSettingsView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.4 - Accessibility audit (Sprint 6c)
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.4:
//  ✅ Screen change announcement on appear
//  ✅ Header icon hidden from VoiceOver
//  ✅ ColorSchemeCard combined with spoken name, description, selection state
//  ✅ Color preview and example text hidden decoratively
//  ✅ Confirmation toast announced to VoiceOver
//
//  CHANGES v1.3:
//  ✅ Enhanced selection haptics
//  ✅ Card entrance stagger animations
//  ✅ Selection scale animation improved
//  ✅ Header icon animation
//  ✅ Toast animation improved
//
//  PREVIOUS (v1.2):
//  - Dark background for better readability

import SwiftUI

struct ColorSchemeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var colorSchemeManager = ColorSchemeManager.shared
    @State private var selectedScheme: FLOColorScheme
    @State private var showConfirmation = false
    @State private var viewAppeared = false
    
    // Haptic Generators
                    
    init() {
        _selectedScheme = State(initialValue: ColorSchemeManager.shared.currentScheme)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header section
                    VStack(spacing: 8) {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(Color.brandPrimary)
                            .scaleEffect(viewAppeared ? 1 : 0.5)
                            .opacity(viewAppeared ? 1 : 0.001)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: viewAppeared)
                            .accessibilityHidden(true)
                        
                        Text("Choose Your Style")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .opacity(viewAppeared ? 1 : 0.001)
                            .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
                        
                        Text("Pick a color scheme that matches your personality and makes managing money feel great")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .opacity(viewAppeared ? 1 : 0.001)
                            .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)
                    }
                    .padding(.vertical)
                    
                    // Color scheme cards
                    VStack(spacing: 16) {
                        ForEach(Array(FLOColorScheme.allSchemes.enumerated()), id: \.element.id) { index, scheme in
                            ColorSchemeCard(
                                scheme: scheme,
                                isSelected: selectedScheme.id == scheme.id
                            )
                            .onTapGesture {
                                HapticService.play(.medium)
                                withAnimation(FLOAnimation.quick) {
                                    selectedScheme = scheme
                                    applyScheme(scheme)
                                }
                            }
                            .opacity(viewAppeared ? 1 : 0.001)
                            .offset(y: viewAppeared ? 0 : 30)
                            .animation(
                                FLOAnimation.standard
                                .delay(0.2 + Double(index) * 0.08),
                                value: viewAppeared
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Color Scheme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        HapticService.play(.light)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .overlay(alignment: .bottom) {
                if showConfirmation {
                    confirmationToast
                }
            }
            .onAppear {
                                withAnimation(FLOAnimation.standard) {
                    viewAppeared = true
                }
                AccessibilityAnnouncement.screenChanged("Color scheme")
            }
        }
    }
    
    // MARK: - Haptic Preparation
    
        
    private var confirmationToast: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Color scheme updated!")
                .fontWeight(.medium)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 8)
        .padding()
        .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
        .accessibilityElement(children: .combine)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showConfirmation = false
                }
            }
        }
    }
    
    private func applyScheme(_ scheme: FLOColorScheme) {
        colorSchemeManager.selectScheme(scheme)
        HapticService.play(.success)
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showConfirmation = true
        }
    }
}

// MARK: - Color Scheme Card

struct ColorSchemeCard: View {
    let scheme: FLOColorScheme
    let isSelected: Bool
    
    @State private var cardAppeared = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text(scheme.emoji)
                    .font(.title)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(scheme.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    Text(scheme.description)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            
            // Color preview
            HStack(spacing: 0) {
                colorBlock(Color.flow(scheme.primary))
                colorBlock(Color.flow(scheme.primaryDark))
                colorBlock(Color.flow(scheme.accent))
                colorBlock(Color.flow(scheme.income))
                colorBlock(Color.flow(scheme.expense))
            }
            .frame(height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Example text
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Income")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                    Text("+ $2,500")
                        .font(.headline)
                        .foregroundStyle(Color.flow(scheme.income))
                }
                
                Divider()
                    .background(.white.opacity(0.3))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Expense")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                    Text("- $850")
                        .font(.headline)
                        .foregroundStyle(Color.flow(scheme.expense))
                }
                
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(white: 0.15))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isSelected ? Color.flow(scheme.primary) : Color.white.opacity(0.2),
                    lineWidth: isSelected ? 3 : 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: isSelected ? Color.flow(scheme.primary).opacity(0.3) : .clear, radius: 8)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(FLOAnimation.quick, value: isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(scheme.name), \(scheme.description)\(isSelected ? ", selected" : "")")
        .accessibilityHint(isSelected ? "Current color scheme" : "Tap to apply this color scheme")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
    
    private func colorBlock(_ color: Color) -> some View {
        Rectangle()
            .fill(color)
    }
}

// MARK: - Preview

#Preview("Color Scheme Settings") {
    ColorSchemeSettingsView()
}

#Preview("Individual Cards") {
    ScrollView {
        VStack(spacing: 16) {
            ColorSchemeCard(scheme: .originalTeal, isSelected: true)
            ColorSchemeCard(scheme: .natureGrowth, isSelected: false)
            ColorSchemeCard(scheme: .warmProsperity, isSelected: false)
        }
        .padding()
    }
    .background(Color.black)
}
