//  EditCategoryView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.0 — Schedule C Line Picker for business expense categories
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v3.0:
//  ✅ ADDED: selectedScheduleCLine state — initialized from category.scheduleCLine
//  ✅ ADDED: scheduleCLineSection — NavigationLink picker, visible when !isIncome && isBusiness && isTaxDeductible
//  ✅ UPDATED: save() writes selectedScheduleCLine back to category
//  ✅ PRESERVED: All v2.5 tax treatment, tax owner, business/personal classification
//  ✅ PRESERVED: All haptics, entrance animations, VoiceOver labels, and dark mode colors
//  ✅ NOTE: ScheduleCLinePickerView defined in AddCategoryView.swift (shared)
//
//  CHANGES v2.5:
//  ✅ ADDED: isBusiness toggle, taxTreatmentSection, taxOwnerSection, withholdingRateSection
//
//  CHANGES v2.4 — VoiceOver Audit:
//  ✅ IconButton/ColorButton accessibility labels and isSelected traits
//
//  CHANGES v2.3 — Dynamic Type Verification:
//  ✅ Default warning and tax deductible footer lineLimit + minimumScaleFactor
//
//  CHANGES v2.1:
//  ✅ Haptics, selection animations, section entrance animations, delete confirmation haptic
//

import SwiftUI
import SwiftData

struct EditCategoryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let category: Category

    // MARK: - State — Core (preserved from v2.4)
    @State private var name: String
    @State private var selectedIcon: String
    @State private var selectedColor: String
    @State private var isTaxDeductible: Bool
    @State private var showingDeleteAlert = false
    @State private var viewAppeared = false

    // MARK: - State — v2.5
    @State private var isBusiness: Bool
    @State private var selectedTaxTreatment: TaxTreatment
    @State private var selectedTaxOwner: TaxOwner
    @State private var withholdingRateText: String

    // MARK: - State — v3.0
    @State private var selectedScheduleCLine: ScheduleCLine?

    // MARK: - Icon / Color Data

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

    /// Whether the Schedule C line picker should be visible
    private var showScheduleCPicker: Bool {
        !category.isIncome && isBusiness && isTaxDeductible
    }

    // MARK: - Init

    init(category: Category) {
        self.category = category
        _name            = State(initialValue: category.name)
        _selectedIcon    = State(initialValue: category.icon)
        _selectedColor   = State(initialValue: category.colorHex)
        _isTaxDeductible = State(initialValue: category.isTaxDeductible)

        // v2.5 — initialize from persisted category properties
        _isBusiness           = State(initialValue: category.isBusiness)
        _selectedTaxTreatment = State(initialValue: category.taxTreatment)
        _selectedTaxOwner     = State(initialValue: category.taxOwner)

        // Format stored decimal rate as percentage string: 0.22 -> "22"
        if let rate = category.estimatedWithholdingRate, rate > 0 {
            let pct = rate * 100
            let formatted = pct.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(pct))
                : String(pct)
            _withholdingRateText = State(initialValue: formatted)
        } else {
            _withholdingRateText = State(initialValue: "")
        }

        // v3.0 — initialize Schedule C line from persisted value
        _selectedScheduleCLine = State(initialValue: category.scheduleCLine)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)

                defaultCategoryWarning

                businessPersonalSection
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)

                taxTreatmentSection
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)

                taxOwnerSection
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)

                withholdingRateSection
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.25), value: viewAppeared)

                iconSection
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.3), value: viewAppeared)

                colorSection
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.35), value: viewAppeared)

                taxDeductibleSection
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.4), value: viewAppeared)

                // v3.0 — Schedule C line picker
                scheduleCLineSection
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.45), value: viewAppeared)

                if !category.isDefault {
                    deleteSection
                        .opacity(viewAppeared ? 1 : 0.001)
                        .offset(y: viewAppeared ? 0 : 10)
                        .animation(FLOAnimation.standard.delay(0.5), value: viewAppeared)
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
                AccessibilityAnnouncement.screenChanged("Edit category")
            }
        }
    }

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
                        .accessibilityHidden(true)
                    Text("Default categories cannot be renamed")
                        .font(.caption)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                }
            }
            .transition(.opacity)
        }
    }

    private var businessPersonalSection: some View {
        Section {
            Toggle(isOn: $isBusiness) {
                Label {
                    Text(isBusiness ? "Business" : "Personal")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } icon: {
                    Image(systemName: isBusiness ? "briefcase.fill" : "house.fill")
                        .foregroundStyle(isBusiness ? Color.brandPrimary : .secondary)
                        .accessibilityHidden(true)
                }
            }
            .onChange(of: isBusiness) { _, newValue in
                HapticService.play(.light)
                if !newValue {
                    selectedScheduleCLine = nil
                }
            }
        } header: {
            Text("Classification")
        } footer: {
            Text(category.isIncome
                 ? "Business income is included in tax reporting. Personal income is tracked separately."
                 : "Business expenses may be tax-deductible. Personal expenses are tracked for budgeting only.")
                .font(.caption)
                .lineLimit(4)
                .minimumScaleFactor(0.7)
        }
    }

    @ViewBuilder
    private var taxTreatmentSection: some View {
        if category.isIncome {
            Section {
                NavigationLink {
                    TaxTreatmentPickerView(selectedTreatment: $selectedTaxTreatment)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: selectedTaxTreatment.icon)
                            .foregroundStyle(selectedTaxTreatment.color)
                            .frame(width: 24)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tax Treatment")
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text(selectedTaxTreatment.displayName)
                                .font(.caption)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityLabel("Tax treatment: \(selectedTaxTreatment.displayName). Tap to change.")
            } header: {
                Text("Tax Treatment")
            } footer: {
                Text(selectedTaxTreatment.description)
                    .font(.caption)
                    .lineLimit(4)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    @ViewBuilder
    private var taxOwnerSection: some View {
        if category.isIncome {
            Section {
                NavigationLink {
                    TaxOwnerPickerView(selectedOwner: $selectedTaxOwner)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: selectedTaxOwner.icon)
                            .foregroundStyle(Color.brandPrimary)
                            .frame(width: 24)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Income Owner")
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text(selectedTaxOwner.displayName)
                                .font(.caption)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityLabel("Income owner: \(selectedTaxOwner.displayName). Tap to change.")
            } footer: {
                Text(selectedTaxOwner.description)
                    .font(.caption)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    @ViewBuilder
    private var withholdingRateSection: some View {
        if category.isIncome && selectedTaxTreatment == .w2WithholdingPaid {
            Section {
                HStack {
                    Text("Estimated Withholding Rate")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                    TextField("e.g. 22", text: $withholdingRateText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                        .accessibilityLabel("Estimated withholding rate percentage")
                    Text("%")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            } header: {
                Text("Employer Withholding")
            } footer: {
                Text("The percentage your employer withholds each paycheck (shown on your pay stub). FLO credits this amount against your quarterly estimated payment.")
                    .font(.caption)
                    .lineLimit(5)
                    .minimumScaleFactor(0.7)
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

    @ViewBuilder
    private var taxDeductibleSection: some View {
        if !category.isIncome {
            Section {
                Toggle("Tax Deductible", isOn: $isTaxDeductible)
                    .onChange(of: isTaxDeductible) { _, newValue in
                        HapticService.play(.light)
                        if !newValue {
                            selectedScheduleCLine = nil
                        }
                    }
            } footer: {
                Text("Tax deductible categories help you track business expenses for tax reporting")
                    .font(.caption)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    // MARK: - Schedule C Line Section (v3.0)

    @ViewBuilder
    private var scheduleCLineSection: some View {
        if showScheduleCPicker {
            Section {
                NavigationLink {
                    ScheduleCLinePickerView(selectedLine: $selectedScheduleCLine)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .foregroundStyle(selectedScheduleCLine != nil ? Color.brandPrimary : .secondary)
                            .frame(width: 24)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Schedule C Line")
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text(selectedScheduleCLine?.displayName ?? "Not assigned")
                                .font(.caption)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityLabel("Schedule C line: \(selectedScheduleCLine?.displayName ?? "Not assigned"). Tap to change.")
            } header: {
                Text("IRS Schedule C")
            } footer: {
                Text("Maps this expense to the correct line on IRS Schedule C (Form 1040). This helps generate CPA-ready tax reports with line-by-line breakdowns.")
                    .font(.caption)
                    .lineLimit(5)
                    .minimumScaleFactor(0.7)
            }
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

    // MARK: - Save

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        // Name (protected for default categories)
        if !category.isDefault {
            category.name = trimmedName
        }

        // Core appearance
        category.icon     = selectedIcon
        category.colorHex = selectedColor

        // Classification
        category.isBusiness = isBusiness

        // Expense-only properties
        if !category.isIncome {
            category.isTaxDeductible = isTaxDeductible
        }

        // Income-only properties
        if category.isIncome {
            category.taxTreatment = selectedTaxTreatment
            category.taxOwner     = selectedTaxOwner

            if selectedTaxTreatment == .w2WithholdingPaid,
               let raw = Double(withholdingRateText),
               raw > 0, raw <= 100 {
                category.estimatedWithholdingRate = raw / 100.0
            } else {
                category.estimatedWithholdingRate = nil
            }
        }

        // v3.0 — Schedule C line (business deductible expenses only)
        if showScheduleCPicker {
            category.scheduleCLine = selectedScheduleCLine
        } else {
            category.scheduleCLine = nil
        }

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

// MARK: - Icon Button Component (v2.4 — unchanged)

private struct IconButton: View {
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Image(systemName: icon)
            .font(.title2)
            .foregroundStyle(isSelected ? color : .secondary)
            .frame(width: 50, height: 50)
            .background(isSelected ? color.opacity(0.15) : Color.gray.opacity(0.1))
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
            .accessibilityLabel("Icon: \(iconDisplayName)")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var iconDisplayName: String {
        icon.replacingOccurrences(of: ".fill", with: "")
            .replacingOccurrences(of: ".", with: " ")
            .capitalized
    }
}

// MARK: - Color Button Component (v2.4 — unchanged)

private struct ColorButton: View {
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
            .accessibilityLabel("Color: \(colorDisplayName)")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var colorDisplayName: String {
        let colorNames: [String: String] = [
            "EF4444": "Red",    "F97316": "Orange", "F59E0B": "Amber",
            "84CC16": "Lime",   "22C55E": "Green",  "10B981": "Emerald",
            "14B8A6": "Teal",   "06B6D4": "Cyan",   "3B82F6": "Blue",
            "8B5CF6": "Purple", "EC4899": "Pink",   "F43F5E": "Rose"
        ]
        return colorNames[color] ?? "Color \(color)"
    }
}

// MARK: - Previews

#Preview("Edit Expense Category") {
    let container = try! ModelContainer(
        for: Category.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let category = Category(
        name: "Groceries",
        icon: "cart.fill",
        colorHex: "10B981",
        isIncome: false,
        isTaxDeductible: false,
        isBusiness: false
    )
    container.mainContext.insert(category)
    return EditCategoryView(category: category)
        .modelContainer(container)
}

#Preview("Edit Business Expense — Schedule C") {
    let container = try! ModelContainer(
        for: Category.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let category = Category(
        name: "Office Supplies",
        icon: "pencil.and.ruler.fill",
        colorHex: "F59E0B",
        isDefault: true,
        isIncome: false,
        isTaxDeductible: true,
        isBusiness: true,
        scheduleCLine: .line18_officeExpense
    )
    container.mainContext.insert(category)
    return EditCategoryView(category: category)
        .modelContainer(container)
}

#Preview("Edit Income Category — W-2") {
    let container = try! ModelContainer(
        for: Category.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let category = Category(
        name: "Spouse Salary",
        icon: "building.columns.fill",
        colorHex: "3B82F6",
        isIncome: true,
        isTaxDeductible: false,
        isBusiness: false,
        taxTreatment: .w2WithholdingPaid,
        taxOwner: .spouse,
        estimatedWithholdingRate: 0.22
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
        isTaxDeductible: false,
        isBusiness: false
    )
    container.mainContext.insert(category)
    return EditCategoryView(category: category)
        .modelContainer(container)
}
