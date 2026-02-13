//  CategoryManagementView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.3 - Accessibility audit (Sprint 5d)
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.3:
//  ✅ Full VoiceOver accessibility coverage
//  ✅ Screen change announcement on appear
//  ✅ Add category button labeled with hint
//  ✅ CategoryRow combined with spoken name, badges, and edit hint
//  ✅ Decorative chevrons hidden from VoiceOver
//  ✅ Fixed garbled UTF-8 characters
//
//  CHANGES v1.2:
//  ✅ FIXED: "Failed to create image slot" error during navigation
//  ✅ Changed opacity from 0 to 0.001 to prevent zero-height calculations
//
//  PREVIOUS (v1.1):
//  - Haptic feedback on row tap/edit
//  - Haptic on delete swipe action
//  - Haptic on add button
//  - Row entrance animations
//  - Icon scale animation on appear
//  - Badge entrance animations

import SwiftUI
import SwiftData

struct CategoryManagementView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Category.name) private var categories: [Category]
    
    @State private var showingAddCategory = false
    @State private var categoryToEdit: Category?
    @State private var viewAppeared = false
    
    var expenseCategories: [Category] {
        categories.filter { !$0.isIncome }
    }
    
    var incomeCategories: [Category] {
        categories.filter { $0.isIncome }
    }
    
    var body: some View {
        List {
            Section("Expense Categories") {
                ForEach(Array(expenseCategories.enumerated()), id: \.element.id) { index, category in
                    CategoryRow(category: category)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            HapticService.play(.light)
                            categoryToEdit = category
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if !category.isDefault {
                                Button(role: .destructive) {
                                    HapticService.play(.heavy)
                                    deleteCategory(category)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                HapticService.play(.medium)
                                categoryToEdit = category
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        .opacity(viewAppeared ? 1 : 0.001)
                        .offset(x: viewAppeared ? 0 : 20)
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.8)
                            .delay(Double(index) * 0.03),
                            value: viewAppeared
                        )
                }
            }
            
            Section("Income Categories") {
                ForEach(Array(incomeCategories.enumerated()), id: \.element.id) { index, category in
                    CategoryRow(category: category)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            HapticService.play(.light)
                            categoryToEdit = category
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if !category.isDefault {
                                Button(role: .destructive) {
                                    HapticService.play(.heavy)
                                    deleteCategory(category)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                HapticService.play(.medium)
                                categoryToEdit = category
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        .opacity(viewAppeared ? 1 : 0.001)
                        .offset(x: viewAppeared ? 0 : 20)
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.8)
                            .delay(0.15 + Double(index) * 0.03),
                            value: viewAppeared
                        )
                }
            }
        }
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    HapticService.play(.medium)
                    showingAddCategory = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(AppConstants.primaryColor)
                }
                .accessibilityLabel("Add category")
                .accessibilityHint("Creates a new expense or income category")
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            AddCategoryView()
        }
        .sheet(item: $categoryToEdit) { category in
            EditCategoryView(category: category)
        }
        .onAppear {
            withAnimation(FLOAnimation.standard) {
                viewAppeared = true
            }
            AccessibilityAnnouncement.screenChanged("Categories")
        }
    }
    
    private func deleteCategory(_ category: Category) {
        withAnimation(FLOAnimation.quick) {
            context.delete(category)
        }
        
        do {
            try context.save()
            HapticService.play(.success)
        } catch {
            HapticService.play(.error)
        }
    }
}

// MARK: - Category Row

struct CategoryRow: View {
    let category: Category
    
    @State private var iconAppeared = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.title3)
                .foregroundStyle(Color(flowHex: category.colorHex))
                .frame(width: 40, height: 40)
                .background(Color(flowHex: category.colorHex).opacity(0.1))
                .cornerRadius(10)
                .scaleEffect(iconAppeared ? 1 : 0.5)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: iconAppeared)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    if category.isDefault {
                        Text("Default")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    if category.isTaxDeductible {
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
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel({
            var label = category.name
            if category.isDefault { label += ", default" }
            if category.isTaxDeductible { label += ", tax deductible" }
            return label
        }())
        .accessibilityHint("Tap to edit, swipe for more options")
        .onAppear {
            iconAppeared = true
        }
    }
}

#Preview {
    NavigationStack {
        CategoryManagementView()
    }
    .modelContainer(for: Category.self, inMemory: true)
}
