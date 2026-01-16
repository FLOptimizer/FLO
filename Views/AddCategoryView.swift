//  AddCategoryView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.2 - Enhanced haptics and micro-animations
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v2.2:
//  ✅ Haptic feedback on icon selection
//  ✅ Haptic on color selection
//  ✅ Haptic on type toggle
//  ✅ Haptic on save/cancel
//  ✅ Icon/color selection animations
//  ✅ Preview card animation
//  ✅ Success/error haptics
//
//  PREVIOUS (v2.1):
//  - Fixed Color(flowHex:), extracted icon grid

import SwiftUI
import SwiftData

struct AddCategoryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var selectedIcon = "folder.fill"
    @State private var selectedColor = "3B82F6"
    @State private var isIncome = false
    @State private var isTaxDeductible = false
    @State private var viewAppeared = false
    
    // Haptic Generators
                    
    private let commonIcons = [
        "cart.fill", "fork.knife", "car.fill", "house.fill", "bolt.fill",
        "gamecontroller.fill", "cross.case.fill", "bag.fill", "briefcase.fill",
        "book.fill", "gift.fill", "airplane", "bed.double.fill", "phone.fill",
        "tv.fill", "scissors", "wrench.fill", "paintbrush.fill", "leaf.fill",
        "dollarsign.circle.fill", "creditcard.fill", "banknote.fill"
    ]
    
    private let commonColors = [
        "EF4444", "F97316", "F59E0B", "84CC16", "22C55E",
        "10B981", "14B8A6", "06B6D4", "3B82F6", "8B5CF6",
        "EC4899", "F43F5E"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                nameSection
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)
                
                typeSection
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
                
                iconSection
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)
                
                colorSection
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)
                
                taxDeductibleSection
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.25), value: viewAppeared)
                
                previewSection
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.3), value: viewAppeared)
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticService.play(.light)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        HapticService.play(.medium)
                        save()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                                withAnimation(FLOAnimation.standard) {
                    viewAppeared = true
                }
            }
        }
    }
    
    // MARK: - Haptic Preparation
    
        
    // MARK: - Sections
    
    private var nameSection: some View {
        Section("Name") {
            TextField("Category name", text: $name)
        }
    }
    
    private var typeSection: some View {
        Section("Type") {
            Picker("Type", selection: $isIncome) {
                Text("Expense").tag(false)
                Text("Income").tag(true)
            }
            .pickerStyle(.segmented)
            .onChange(of: isIncome) { _, _ in
                HapticService.play(.selection)
            }
        }
    }
    
    private var iconSection: some View {
        Section("Icon") {
            ScrollView(.horizontal, showsIndicators: false) {
                iconGrid
            }
        }
    }
    
    private var iconGrid: some View {
        LazyHGrid(
            rows: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ],
            spacing: 12
        ) {
            ForEach(commonIcons, id: \.self) { icon in
                IconButton(
                    icon: icon,
                    isSelected: selectedIcon == icon,
                    color: Color(flowHex: selectedColor)
                ) {
                    HapticService.play(.selection)
                    withAnimation(FLOAnimation.quick) {
                        selectedIcon = icon
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private var colorSection: some View {
        Section("Color") {
            ScrollView(.horizontal, showsIndicators: false) {
                colorGrid
            }
        }
    }
    
    private var colorGrid: some View {
        LazyHGrid(
            rows: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ],
            spacing: 12
        ) {
            ForEach(commonColors, id: \.self) { color in
                ColorButton(
                    color: color,
                    isSelected: selectedColor == color
                ) {
                    HapticService.play(.selection)
                    withAnimation(FLOAnimation.quick) {
                        selectedColor = color
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private var taxDeductibleSection: some View {
        Section {
            Toggle("Tax Deductible", isOn: $isTaxDeductible)
                .onChange(of: isTaxDeductible) { _, _ in
                    HapticService.play(.light)
                }
        }
    }
    
    private var previewSection: some View {
        Section("Preview") {
            HStack(spacing: 12) {
                Image(systemName: selectedIcon)
                    .font(.title3)
                    .foregroundStyle(Color(flowHex: selectedColor))
                    .frame(width: 40, height: 40)
                    .background(Color(flowHex: selectedColor).opacity(0.1))
                    .cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(name.isEmpty ? "Category Name" : name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(name.isEmpty ? .secondary : .primary)
                    
                    HStack(spacing: 8) {
                        Text(isIncome ? "Income" : "Expense")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(isIncome ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                            .foregroundStyle(isIncome ? .green : .red)
                            .cornerRadius(4)
                        
                        if isTaxDeductible {
                            Text("Tax Deductible")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .foregroundStyle(.green)
                                .cornerRadius(4)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }
            .animation(FLOAnimation.quick, value: isTaxDeductible)
        }
    }
    
    // MARK: - Actions
    
    private func save() {
        let category = Category(
            name: name,
            icon: selectedIcon,
            colorHex: selectedColor,
            isDefault: false,
            isIncome: isIncome,
            isTaxDeductible: isTaxDeductible
        )
        context.insert(category)
        
        do {
            try context.save()
            HapticService.play(.success)
        } catch {
            HapticService.play(.error)
            print("❌ Failed to save category: \(error)")
        }
    }
}

// MARK: - Icon Button Component

struct IconButton: View {
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Image(systemName: icon)
            .font(.title2)
            .foregroundStyle(isSelected ? color : .secondary)
            .frame(width: 50, height: 50)
            .background(isSelected ? color.opacity(0.15) : Color(.systemGray6))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(FLOAnimation.quick, value: isSelected)
            .onTapGesture {
                action()
            }
            .accessibilityLabel("Icon: \(icon)")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Color Button Component

struct ColorButton: View {
    let color: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Circle()
            .fill(Color(flowHex: color))
            .frame(width: 50, height: 50)
            .overlay(
                Circle()
                    .stroke(Color.primary, lineWidth: isSelected ? 3 : 0)
            )
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: isSelected ? 1.5 : 0)
                    .padding(1.5)
            )
            .scaleEffect(isSelected ? 1.1 : 1.0)
            .animation(FLOAnimation.quick, value: isSelected)
            .onTapGesture {
                action()
            }
            .accessibilityLabel("Color: \(color)")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Preview

#Preview("Add Category") {
    AddCategoryView()
        .modelContainer(for: Category.self, inMemory: true)
}
