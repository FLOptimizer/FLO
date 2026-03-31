//  AddCategoryView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.0 — Schedule C Line Picker for business expense categories
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v3.0:
//  ✅ ADDED: selectedScheduleCLine state — optional ScheduleCLine for business expenses
//  ✅ ADDED: scheduleCLineSection — NavigationLink picker, visible when !isIncome && isBusiness && isTaxDeductible
//  ✅ ADDED: Schedule C badge in preview section (shows "Ln 8", "Ln 24b", etc.)
//  ✅ UPDATED: previewAccessibilityLabel includes Schedule C line when set
//  ✅ UPDATED: save() passes selectedScheduleCLine to Category init
//  ✅ ADDED: ScheduleCLinePickerView — shared with EditCategoryView
//  ✅ PRESERVED: All v2.5 tax treatment, tax owner, business/personal classification
//  ✅ PRESERVED: All haptics, entrance animations, VoiceOver labels, and dark mode colors
//
//  CHANGES v2.5:
//  ✅ ADDED: isBusiness toggle, taxTreatmentSection, taxOwnerSection, withholdingRateSection
//
//  CHANGES v2.4 — Dynamic Type Verification:
//  ✅ FIXED: Preview category name, type badge, tax deductible badge text
//
//  CHANGES v2.2:
//  ✅ Haptic feedback, icon/color/toggle selection animations, success/error haptics
//

import SwiftUI
import FLODesignSystem
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

    // MARK: - State — v2.5
    @State private var isBusiness = false
    @State private var selectedTaxTreatment: TaxTreatment = .selfEmployment
    @State private var selectedTaxOwner: TaxOwner = .primary
    @State private var withholdingRateText = ""

    // MARK: - State — v3.0
    @State private var selectedScheduleCLine: ScheduleCLine? = nil

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
        !isIncome && isBusiness && isTaxDeductible
    }

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

                // Income-only sections
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

                // v3.0 — Schedule C line picker (business + expense + deductible only)
                scheduleCLineSection
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.5), value: viewAppeared)

                previewSection
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.55), value: viewAppeared)
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
                if !newValue {
                    selectedTaxTreatment = .selfEmployment
                    selectedTaxOwner = .primary
                    withholdingRateText = ""
                } else {
                    // Income categories don't have Schedule C lines
                    selectedScheduleCLine = nil
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
            .onChange(of: isBusiness) { _, newValue in
                HapticService.play(.light)
                // Clear Schedule C line if switching to personal
                if !newValue {
                    selectedScheduleCLine = nil
                }
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
                    .onChange(of: isTaxDeductible) { _, newValue in
                        HapticService.play(.light)
                        // Clear Schedule C line if no longer deductible
                        if !newValue {
                            selectedScheduleCLine = nil
                        }
                    }
            } footer: {
                Text("Tax deductible categories help you track business expenses for tax reporting.")
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

    // MARK: - Preview

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

                    // Scrollable badge row
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

                            // v3.0 — Schedule C line badge
                            if let line = selectedScheduleCLine {
                                Text(line.badgeLabel)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.indigo.opacity(0.15))
                                    .foregroundStyle(.indigo)
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
            .animation(FLOAnimation.quick, value: selectedScheduleCLine?.rawValue)
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
        if let line = selectedScheduleCLine { parts.append(line.displayName) }
        return parts.joined(separator: ", ")
    }

    // MARK: - Save

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        // Convert withholding text "22" -> 0.22; only for W-2 categories
        let withholdingRate: Double? = {
            guard selectedTaxTreatment == .w2WithholdingPaid,
                  let raw = Double(withholdingRateText),
                  raw > 0, raw <= 100 else { return nil }
            return raw / 100.0
        }()

        // Only pass scheduleCLine for business deductible expenses
        let finalScheduleCLine: ScheduleCLine? = showScheduleCPicker ? selectedScheduleCLine : nil

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
            estimatedWithholdingRate: withholdingRate,
            scheduleCLine: finalScheduleCLine
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

// MARK: - Schedule C Line Picker View (v3.0 — shared with EditCategoryView)

/// NavigationLink destination for selecting a ScheduleCLine.
/// Shows only expense lines (not income lines 1/6) sorted by line number.
/// Includes a "None" option to clear the assignment.
struct ScheduleCLinePickerView: View {
    @Binding var selectedLine: ScheduleCLine?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            // "None" option to clear assignment
            Button {
                selectedLine = nil
                HapticService.play(.selection)
                dismiss()
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(.secondary)
                        .frame(width: 28)
                        .accessibilityHidden(true)

                    Text("Not Assigned")
                        .foregroundStyle(.primary)

                    Spacer()

                    if selectedLine == nil {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.brandPrimary)
                            .fontWeight(.semibold)
                            .accessibilityHidden(true)
                    }
                }
                .padding(.vertical, 4)
            }
            .accessibilityLabel("Not assigned")
            .accessibilityAddTraits(selectedLine == nil ? .isSelected : [])

            // Common expense lines (most relevant for freelancers)
            Section("Common Lines") {
                ForEach(ScheduleCLine.commonExpenseLines, id: \.rawValue) { line in
                    scheduleCLineRow(line)
                }
            }

            // All other expense lines
            Section("All Expense Lines") {
                ForEach(ScheduleCLine.expenseLines.filter { !ScheduleCLine.commonExpenseLines.contains($0) }, id: \.rawValue) { line in
                    scheduleCLineRow(line)
                }
            }
        }
        .navigationTitle("Schedule C Line")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            AccessibilityAnnouncement.screenChanged("Schedule C line")
        }
    }

    private func scheduleCLineRow(_ line: ScheduleCLine) -> some View {
        Button {
            selectedLine = line
            HapticService.play(.selection)
            dismiss()
        } label: {
            HStack(spacing: 14) {
                Text(line.badgeLabel)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 24)
                    .background(Color.indigo)
                    .cornerRadius(6)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(line.irsDescription)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.primary)
                    Text(line.lineNumber)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if selectedLine == line {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.brandPrimary)
                        .fontWeight(.semibold)
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, 4)
        }
        .accessibilityLabel("\(line.displayName). \(line.irsDescription)")
        .accessibilityAddTraits(selectedLine == line ? .isSelected : [])
    }
}

// MARK: - Preview

#Preview("Add Category") {
    AddCategoryView()
        .modelContainer(for: Category.self, inMemory: true)
}
