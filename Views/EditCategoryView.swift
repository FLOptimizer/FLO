//  EditCategoryView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.1 - Enhanced haptics and micro-animations
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v2.1:
//  ✅ Comprehensive haptic preparation
//  ✅ Selection animations for icons/colors
//  ✅ Section entrance animations
//  ✅ Delete confirmation haptic
//  ✅ Enhanced icon/color components
//
//  PREVIOUS (v2.0.1):
//  - Basic haptic on save/delete

import SwiftUI
import SwiftData

struct EditCategoryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    let category: Category
    
    @State private var name: String
    @State private var selectedIcon: String
    @State private var selectedColor: String
    @State private var isTaxDeductible: Bool
    @State private var showingDeleteAlert = false
    @State private var viewAppeared = false
    
    // Haptic Generators
                        
    init(category: Category) {
        self.category = category
        _name = State(initialValue: category.name)
        _selectedIcon = State(initialValue: category.icon)
        _selectedColor = State(initialValue: category.colorHex)
        _isTaxDeductible = State(initialValue: category.isTaxDeductible)
    }
    
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
                
                defaultCategoryWarning
                
                iconSection
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
                
                colorSection
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)
                
                taxDeductibleSection
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)
                
                if !category.isDefault {
                    deleteSection
                        .opacity(viewAppeared ? 1 : 0)
                        .offset(y: viewAppeared ? 0 : 10)
                        .animation(FLOAnimation.standard.delay(0.25), value: viewAppeared)
                }
            }
            .navigationTitle("Edit Category")
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
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Delete Category", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteCategory()
                }
            } message: {
                Text("Are you sure you want to delete this category? This action cannot be undone.")
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
                .disabled(category.isDefault)
        }
    }
    
    @ViewBuilder
    private var defaultCategoryWarning: some View {
        if category.isDefault {
            Section {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.orange)
                    Text("Default categories cannot be renamed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .transition(.opacity)
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
        } footer: {
            Text("Tax deductible categories help you track business expenses for tax reporting")
                .font(.caption)
        }
    }
    
    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                HapticService.play(.heavy)
                showingDeleteAlert = true
            } label: {
                HStack {
                    Spacer()
                    Text("Delete Category")
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        if !category.isDefault {
            category.name = trimmedName
        }
        category.icon = selectedIcon
        category.colorHex = selectedColor
        category.isTaxDeductible = isTaxDeductible
        
        do {
            try context.save()
            HapticService.play(.success)
            dismiss()
        } catch {
            HapticService.play(.error)
            print("❌ Failed to save category: \(error)")
        }
    }
    
    private func deleteCategory() {
        context.delete(category)
        
        do {
            try context.save()
            HapticService.play(.success)
            dismiss()
        } catch {
            HapticService.play(.error)
            print("❌ Failed to delete category: \(error)")
        }
    }
}

// MARK: - Preview

#Preview("Edit Category") {
    let container = try! ModelContainer(
        for: Category.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    let category = Category(
        name: "Groceries",
        icon: "cart.fill",
        colorHex: "10B981",
        isIncome: false,
        isTaxDeductible: false
    )
    container.mainContext.insert(category)
    
    return EditCategoryView(category: category)
        .modelContainer(container)
}

#Preview("Edit Default Category") {
    let container = try! ModelContainer(
        for: Category.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    let category = Category(
        name: "Uncategorized",
        icon: "folder.fill",
        colorHex: "999999",
        isDefault: true,
        isIncome: false,
        isTaxDeductible: false
    )
    container.mainContext.insert(category)
    
    return EditCategoryView(category: category)
        .modelContainer(container)
}
