//  CategoryManagementView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.6 — Allow deletion of any category (no more isDefault restriction)
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.6:
//  ✅ REMOVED: isDefault check — users can now delete ANY category
//  ✅ ADDED: Warning confirmation when deleting categories with linked transactions
//  ✅ ADDED: "In Use" indicator showing transaction count for each category
//  ✅ NOTE: Category list is now much longer (61 categories in v1.4 seed data)
//           Users should delete categories they don't need to simplify their view
//
//  CHANGES v1.5:
//  ✅ ADDED: Four sections replacing two — Business Expenses, Personal Expenses,
//            Business Income, Personal Income
//  ✅ ADDED: Empty sections are hidden — only visible sections with 1+ categories shown
//  ✅ ADDED: CategoryRow tax treatment badge — shown for all income categories
//  ✅ ADDED: CategoryRow owner badge — shown when taxOwner is .spouse or .joint
//  ✅ UPDATED: CategoryRow badge row uses ScrollView(.horizontal) — badges never clip
//  ✅ UPDATED: CategoryRow accessibilityLabel includes tax treatment and owner for income
//  ✅ UPDATED: Animation delays globally staggered across all four visible sections
//  ✅ PRESERVED: All v1.4 Dynamic Type (lineLimit + minimumScaleFactor) on all text
//  ✅ PRESERVED: All haptics, swipe actions, VoiceOver labels and hints, dark mode colors
//  ✅ PRESERVED: Icon scale animation on appear, row entrance slide animations
//
//  MIGRATION NOTE:
//  isBusiness defaults to false for pre-v2.2 Category records.
//  SeedData.migrateCategories() (v2.7) back-fills isBusiness on first launch.
//  Until then most categories appear in Personal sections — expected, resolves on launch.
//
//  CHANGES v1.4 — Dynamic Type Verification:
//  ✅ CategoryRow name, Default badge, Tax Deductible badge lineLimit + minimumScaleFactor
//
//  CHANGES v1.3:
//  ✅ Full VoiceOver coverage, screen change announcement, decorative chevrons hidden
//
//  CHANGES v1.2:
//  ✅ opacity 0 -> 0.001 to prevent zero-height image slot errors
//
//  PREVIOUS (v1.1):
//  — Haptics, row entrance animations, icon scale animation, badge animations
//

import SwiftUI
import FLODesignSystem
import SwiftData

struct CategoryManagementView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Category.name) private var categories: [Category]

    @State private var showingAddCategory = false
    @State private var categoryToEdit: Category?
    @State private var categoryToDelete: Category?
    @State private var showDeleteConfirmation = false
    @State private var viewAppeared = false

    // MARK: - Computed Category Groups

    var businessExpenseCategories: [Category] {
        categories.filter { !$0.isIncome && $0.isBusiness }
    }

    var personalExpenseCategories: [Category] {
        categories.filter { !$0.isIncome && !$0.isBusiness }
    }

    var businessIncomeCategories: [Category] {
        categories.filter { $0.isIncome && $0.isBusiness }
    }

    var personalIncomeCategories: [Category] {
        categories.filter { $0.isIncome && !$0.isBusiness }
    }

    // MARK: - Row Animation Delay

    /// Staggered delay based on a globally-unique row index across all sections.
    private func rowDelay(globalIndex: Int) -> Double {
        Double(globalIndex) * 0.03
    }

    // MARK: - Body

    var body: some View {
        List {
            categorySection(
                title: "Business Expenses",
                categories: businessExpenseCategories,
                globalOffset: 0
            )

            categorySection(
                title: "Personal Expenses",
                categories: personalExpenseCategories,
                globalOffset: businessExpenseCategories.count
            )

            categorySection(
                title: "Business Income",
                categories: businessIncomeCategories,
                globalOffset: businessExpenseCategories.count
                           + personalExpenseCategories.count
            )

            categorySection(
                title: "Personal Income",
                categories: personalIncomeCategories,
                globalOffset: businessExpenseCategories.count
                           + personalExpenseCategories.count
                           + businessIncomeCategories.count
            )
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
                        .foregroundStyle(Color.brandPrimary)
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
        .alert("Delete Category?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                categoryToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let category = categoryToDelete {
                    performDelete(category)
                }
                categoryToDelete = nil
            }
        } message: {
            if let category = categoryToDelete {
                let count = category.transactionCount
                if count > 0 {
                    Text("This category has \(count) linked transaction\(count == 1 ? "" : "s"). Deleting it will remove the category from those transactions.")
                } else {
                    Text("Are you sure you want to delete \"\(category.name)\"?")
                }
            }
        }
        .onAppear {
            withAnimation(FLOAnimation.standard) {
                viewAppeared = true
            }
            AccessibilityAnnouncement.screenChanged("Categories")
        }
    }

    // MARK: - Section Builder

    /// Renders a named List section for a category group.
    /// Hidden entirely when the group is empty — no empty-state clutter.
    @ViewBuilder
    private func categorySection(
        title: String,
        categories: [Category],
        globalOffset: Int
    ) -> some View {
        if !categories.isEmpty {
            Section(title) {
                ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                    CategoryRow(category: category)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            HapticService.play(.light)
                            categoryToEdit = category
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            // v1.6: Removed isDefault check — all categories can be deleted
                            Button(role: .destructive) {
                                HapticService.play(.heavy)
                                deleteCategory(category)
                            } label: {
                                Label("Delete", systemImage: "trash")
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
                                .delay(rowDelay(globalIndex: globalOffset + index)),
                            value: viewAppeared
                        )
                }
            }
        }
    }

    // MARK: - Delete

    private func deleteCategory(_ category: Category) {
        // v1.6: Show confirmation if category has transactions
        if category.transactionCount > 0 {
            categoryToDelete = category
            showDeleteConfirmation = true
        } else {
            performDelete(category)
        }
    }
    
    private func performDelete(_ category: Category) {
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

            // Icon tile — spring scale animation on appear (v1.1 preserved)
            Image(systemName: category.icon)
                .font(.title3)
                .foregroundStyle(Color(flowHex: category.colorHex))
                .frame(width: 40, height: 40)
                .background(Color(flowHex: category.colorHex).opacity(0.1))
                .cornerRadius(10)
                .scaleEffect(iconAppeared ? 1 : 0.5)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: iconAppeared)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {

                // Name — v1.4 Dynamic Type preserved
                Text(category.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                // Badge row — horizontal scroll handles overflow at large text sizes
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {

                        // v1.6: "In Use" badge shows transaction count
                        if category.transactionCount > 0 {
                            CategoryBadge(
                                label: "\(category.transactionCount) txn\(category.transactionCount == 1 ? "" : "s")",
                                background: Color.secondary.opacity(0.15),
                                foreground: Color.secondary
                            )
                        }

                        // "Tax Deductible" badge (expense) — v1.4 preserved
                        if category.isTaxDeductible {
                            CategoryBadge(
                                label: "Tax Deductible",
                                background: Color.green.opacity(0.2),
                                foreground: .green
                            )
                        }

                        // Tax treatment badge (income only) — v1.5 new
                        if category.isIncome {
                            CategoryBadge(
                                label: category.taxTreatment.badgeLabel,
                                background: category.taxTreatment.color.opacity(0.15),
                                foreground: category.taxTreatment.color
                            )
                        }

                        // Owner badge — only for spouse/joint (primary is implied) — v1.5 new
                        if category.isIncome && category.taxOwner != .primary {
                            CategoryBadge(
                                label: category.taxOwner.displayName,
                                background: Color.brandPrimary.opacity(0.12),
                                foreground: Color.brandPrimary
                            )
                        }
                    }
                    // Padding ensures the first badge isn't flush against the scroll edge
                    .padding(.trailing, 4)
                }
                // Fixed height keeps rows uniform regardless of badge count
                .frame(height: 20)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowAccessibilityLabel)
        .accessibilityHint("Tap to edit, swipe for more options")
        .onAppear {
            iconAppeared = true
        }
    }

    // MARK: - Accessibility Label

    /// Combines all visible badge content into a single VoiceOver statement.
    private var rowAccessibilityLabel: String {
        var parts = [category.name]

        if category.transactionCount > 0 {
            parts.append("\(category.transactionCount) transactions")
        }
        if category.isTaxDeductible { parts.append("tax deductible") }

        if category.isIncome {
            parts.append(category.taxTreatment.displayName)
            if category.taxOwner != .primary {
                parts.append(category.taxOwner.displayName)
            }
        }

        return parts.joined(separator: ", ")
    }
}

// MARK: - Category Badge Helper View

/// Reusable inline badge used by CategoryRow.
/// Extracted to ensure every badge has identical Dynamic Type handling.
private struct CategoryBadge: View {
    let label: String
    let background: Color
    let foreground: Color

    var body: some View {
        Text(label)
            .font(.caption2)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(background)
            .foregroundStyle(foreground)
            .cornerRadius(4)
            .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Preview

#Preview {
    let container = try! ModelContainer(
        for: Category.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let samples: [Category] = [
        // Business Expense
        Category(
            name: "Office Supplies",
            icon: "pencil.and.ruler.fill",
            colorHex: "F59E0B",
            isDefault: false,
            isIncome: false,
            isTaxDeductible: true,
            isBusiness: true
        ),
        Category(
            name: "Software & Subscriptions",
            icon: "app.badge.fill",
            colorHex: "8B5CF6",
            isDefault: false,
            isIncome: false,
            isTaxDeductible: true,
            isBusiness: true
        ),
        // Personal Expense
        Category(
            name: "Groceries",
            icon: "cart.fill",
            colorHex: "10B981",
            isDefault: false,
            isIncome: false,
            isTaxDeductible: false,
            isBusiness: false
        ),
        Category(
            name: "Dining Out",
            icon: "fork.knife",
            colorHex: "F97316",
            isDefault: false,
            isIncome: false,
            isTaxDeductible: false,
            isBusiness: false
        ),
        // Business Income — SE
        Category(
            name: "Freelance Income",
            icon: "dollarsign.circle.fill",
            colorHex: "14B8A6",
            isDefault: false,
            isIncome: true,
            isTaxDeductible: false,
            isBusiness: true,
            taxTreatment: .selfEmployment,
            taxOwner: .primary
        ),
        // Personal Income — W-2 Spouse
        Category(
            name: "Spouse Salary",
            icon: "building.columns.fill",
            colorHex: "3B82F6",
            isDefault: false,
            isIncome: true,
            isTaxDeductible: false,
            isBusiness: false,
            taxTreatment: .w2WithholdingPaid,
            taxOwner: .spouse,
            estimatedWithholdingRate: 0.22
        ),
        // Personal Income — Passive Joint
        Category(
            name: "Investment Income",
            icon: "chart.line.uptrend.xyaxis",
            colorHex: "8B5CF6",
            isDefault: false,
            isIncome: true,
            isTaxDeductible: false,
            isBusiness: false,
            taxTreatment: .passiveIncome,
            taxOwner: .joint
        )
    ]

    for cat in samples {
        container.mainContext.insert(cat)
    }

    return NavigationStack {
        CategoryManagementView()
    }
    .modelContainer(container)
}
