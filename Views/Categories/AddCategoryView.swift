//  AddCategoryView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.5 — Tax Treatment, Tax Owner, and Business/Personal classification
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v2.5:
//  ✅ ADDED: isBusiness toggle — Business or Personal classification for all categories
//  ✅ ADDED: taxTreatmentSection — NavigationLink picker (income categories only)
//  ✅ ADDED: taxOwnerSection — NavigationLink picker (income categories only)
//  ✅ ADDED: withholdingRateSection — estimated withholding % field (W-2 income only)
//  ✅ ADDED: taxDeductibleSection now hidden for income categories (not applicable)
//  ✅ UPDATED: previewSection shows tax treatment badge for income categories
//  ✅ UPDATED: previewAccessibilityLabel includes treatment and owner for income
//  ✅ UPDATED: save() passes all new properties to Category init
//  ✅ ADDED: TaxTreatmentPickerView — shared with EditCategoryView
//  ✅ ADDED: TaxOwnerPickerView — shared with EditCategoryView
//  ✅ PRESERVED: All v2.4 Dynamic Type (lineLimit + minimumScaleFactor) on all text
//  ✅ PRESERVED: All haptics, entrance animations, VoiceOver labels, and dark mode colors
//
//  CHANGES v2.4 — Dynamic Type Verification:
//  ✅ FIXED: Preview category name, type badge, tax deductible badge text
//
//  CHANGES v2.2:
//  ✅ Haptic feedback, icon/color/toggle selection animations, success/error haptics
//
//  PREVIOUS (v2.1):
//  — Fixed Color(flowHex:), extracted icon grid
//

import SwiftUI
import SwiftData

struct AddCategoryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    // MARK: - State — Core (preserved from v2.4)
    @State private var name = ""
    @State private var selectedIcon = "folder.fill"
    @State private var selectedColor = "3B82F6"
    @State private var isIncome = false
    @State private var isTaxDeductible = false
    @State private var viewAppeared = false

    // MARK: - State — New (v2.5)
    @State private var isBusiness = false
    @State private var selectedTaxTreatment: TaxTreatment = .selfEmployment
    @State private var selectedTaxOwner: TaxOwner = .primary
    @State private var withholdingRateText = ""

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

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)

                typeSection
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)

                businessPersonalSection
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)

                // Income-only sections — animate regardless, content conditional
                taxTreatmentSection
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)

                taxOwnerSection
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.25), value: viewAppeared)

                withholdingRateSection
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.3), value: viewAppeared)

                iconSection
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.35), value: viewAppeared)

                colorSection
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.4), value: viewAppeared)

                taxDeductibleSection
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.45), value: viewAppeared)

                previewSection
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.5), value: viewAppeared)
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
                AccessibilityAnnouncement.screenChanged("New category")
            }
        }
    }

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
            .onChange(of: isIncome) { _, newValue in
                HapticService.play(.selection)
                // Reset income-specific fields when switching to expense
                if !newValue {
                    selectedTaxTreatment = .selfEmployment
                    selectedTaxOwner = .primary
                    withholdingRateText = ""
                }
            }
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
            .onChange(of: isBusiness) { _, _ in
                HapticService.play(.light)
            }
        } header: {
            Text("Classification")
        } footer: {
            Text(isIncome
                 ? "Business income is included in tax reporting. Personal income is tracked separately."
                 : "Business expenses may be tax-deductible. Personal expenses are tracked for budgeting only.")
                .font(.caption)
                .lineLimit(4)
                .minimumScaleFactor(0.7)
        }
    }

    @ViewBuilder
    private var taxTreatmentSection: some View {
        if isIncome {
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
        if isIncome {
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
        if isIncome && selectedTaxTreatment == .w2WithholdingPaid {
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
        if !isIncome {
            Section {
                Toggle("Tax Deductible", isOn: $isTaxDeductible)
                    .onChange(of: isTaxDeductible) { _, _ in
                        HapticService.play(.light)
                    }
            } footer: {
                Text("Tax deductible categories help you track business expenses for tax reporting.")
                    .font(.caption)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
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
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(name.isEmpty ? "Category Name" : name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(name.isEmpty ? .secondary : .primary)

                    // Scrollable badge row so all badges stay visible at all text sizes
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            // Income / Expense
                            Text(isIncome ? "Income" : "Expense")
                                .font(.caption2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(isIncome ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                                .foregroundStyle(isIncome ? .green : .red)
                                .cornerRadius(4)

                            // Business badge
                            if isBusiness {
                                Text("Business")
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.brandPrimary.opacity(0.15))
                                    .foregroundStyle(Color.brandPrimary)
                                    .cornerRadius(4)
                                    .transition(.scale.combined(with: .opacity))
                            }

                            // Tax treatment badge — income only
                            if isIncome {
                                Text(selectedTaxTreatment.badgeLabel)
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(selectedTaxTreatment.color.opacity(0.15))
                                    .foregroundStyle(selectedTaxTreatment.color)
                                    .cornerRadius(4)
                                    .transition(.scale.combined(with: .opacity))
                            }

                            // Tax deductible badge — expense only
                            if !isIncome && isTaxDeductible {
                                Text("Tax Deductible")
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
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
            }
            .animation(FLOAnimation.quick, value: isTaxDeductible)
            .animation(FLOAnimation.quick, value: isIncome)
            .animation(FLOAnimation.quick, value: isBusiness)
            .animation(FLOAnimation.quick, value: selectedTaxTreatment.rawValue)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(previewAccessibilityLabel)
        }
    }

    private var previewAccessibilityLabel: String {
        var parts = ["Preview"]
        parts.append(name.isEmpty ? "No name" : name)
        parts.append(isIncome ? "Income" : "Expense")
        if isBusiness { parts.append("Business") }
        if isIncome {
            parts.append(selectedTaxTreatment.displayName)
            parts.append(selectedTaxOwner.displayName)
        }
        if !isIncome && isTaxDeductible { parts.append("Tax deductible") }
        return parts.joined(separator: ", ")
    }

    // MARK: - Save

    private func save() {
        // Convert withholding text "22" -> 0.22; only for W-2 categories
        let withholdingRate: Double? = {
            guard selectedTaxTreatment == .w2WithholdingPaid,
                  let raw = Double(withholdingRateText),
                  raw > 0, raw <= 100 else { return nil }
            return raw / 100.0
        }()

        let category = Category(
            name: name,
            icon: selectedIcon,
            colorHex: selectedColor,
            isDefault: false,
            isIncome: isIncome,
            isTaxDeductible: !isIncome && isTaxDeductible,
            isBusiness: isBusiness,
            taxTreatment: isIncome ? selectedTaxTreatment : .selfEmployment,
            taxOwner: isIncome ? selectedTaxOwner : .primary,
            estimatedWithholdingRate: withholdingRate
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
            .accessibilityLabel("Color: \(color)")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Tax Treatment Picker View (v2.5 — shared with EditCategoryView)

/// NavigationLink destination for selecting a TaxTreatment.
/// Follows the established FLO pattern: StatePickerView / FilingStatusPickerView in TaxSettingsView.
struct TaxTreatmentPickerView: View {
    @Binding var selectedTreatment: TaxTreatment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(TaxTreatment.allCases, id: \.rawValue) { treatment in
                Button {
                    selectedTreatment = treatment
                    HapticService.play(.selection)
                    dismiss()
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: treatment.icon)
                            .foregroundStyle(treatment.color)
                            .frame(width: 28)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(treatment.displayName)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.primary)
                            Text(treatment.description)
                                .font(.caption)
                                .lineLimit(3)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if selectedTreatment == treatment {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.brandPrimary)
                                .fontWeight(.semibold)
                                .accessibilityHidden(true)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .accessibilityLabel("\(treatment.displayName). \(treatment.description)")
                .accessibilityAddTraits(selectedTreatment == treatment ? .isSelected : [])
            }
        }
        .navigationTitle("Tax Treatment")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            AccessibilityAnnouncement.screenChanged("Tax treatment")
        }
    }
}

// MARK: - Tax Owner Picker View (v2.5 — shared with EditCategoryView)

/// NavigationLink destination for selecting a TaxOwner.
struct TaxOwnerPickerView: View {
    @Binding var selectedOwner: TaxOwner
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(TaxOwner.allCases, id: \.rawValue) { owner in
                Button {
                    selectedOwner = owner
                    HapticService.play(.selection)
                    dismiss()
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: owner.icon)
                            .foregroundStyle(Color.brandPrimary)
                            .frame(width: 28)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(owner.displayName)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.primary)
                            Text(owner.description)
                                .font(.caption)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if selectedOwner == owner {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.brandPrimary)
                                .fontWeight(.semibold)
                                .accessibilityHidden(true)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .accessibilityLabel("\(owner.displayName). \(owner.description)")
                .accessibilityAddTraits(selectedOwner == owner ? .isSelected : [])
            }
        }
        .navigationTitle("Income Owner")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            AccessibilityAnnouncement.screenChanged("Income owner")
        }
    }
}

// MARK: - Preview

#Preview("Add Category") {
    AddCategoryView()
        .modelContainer(for: Category.self, inMemory: true)
}
