//  FilingChecklistView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — Filing checklist with required forms and deadlines
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Generates a personalized list of IRS forms and filing deadlines
//  based on the user's business entities, filing status, and state.
//

import SwiftUI
import FLODesignSystem
import SwiftData

struct FilingChecklistView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(
        filter: #Predicate<BusinessProfile> { $0.isActive },
        sort: \BusinessProfile.sortOrder
    )
    private var businesses: [BusinessProfile]

    @Query private var taxSettingsAll: [TaxSettings]

    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date()) - 1
    @State private var checklist: FilingChecklist?
    @State private var completedIDs: Set<UUID> = []
    @State private var viewAppeared = false

    private var hasProAccess: Bool {
        subscriptionManager.currentTier == .pro
    }

    private var taxSettings: TaxSettings? {
        taxSettingsAll.first
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                yearPicker

                if let checklist {
                    summaryCard(checklist)

                    ForEach(sortedCategories(checklist), id: \.self) { category in
                        categorySection(category, checklist: checklist)
                    }

                    disclaimerCard
                } else {
                    ProgressView("Generating checklist...")
                        .padding(40)
                }
            }
            .padding(16)
        }
        .navigationTitle("Filing Checklist")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .onAppear {
            generateChecklist()
            withAnimation(.easeOut(duration: 0.3)) {
                viewAppeared = true
            }
        }
        .onChange(of: selectedYear) { _, _ in
            generateChecklist()
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        ProfileHeaderCard(
            icon: "checklist.checked",
            title: "Filing Requirements",
            subtitle: "Forms and deadlines for \(selectedYear) tax year",
            color: .orange
        )
    }

    // MARK: - Year Picker

    private var yearPicker: some View {
        let currentYear = Calendar.current.component(.year, from: Date())
        let years = Array((currentYear - 2)...(currentYear))

        return Picker("Tax Year", selection: $selectedYear) {
            ForEach(years, id: \.self) { year in
                Text(String(year)).tag(year)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Summary Card

    private func summaryCard(_ checklist: FilingChecklist) -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(checklist.totalForms) Forms Required")
                        .font(.headline)
                    Text("Based on \(businesses.count) \(businesses.count == 1 ? "entity" : "entities")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if checklist.criticalCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .accessibilityHidden(true)
                        Text("\(checklist.criticalCount) due soon")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.red)
                    }
                }
            }

            // Progress bar
            let completedCount = completedIDs.count
            let total = checklist.totalForms
            let progress = total > 0 ? Double(completedCount) / Double(total) : 0

            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: progress)
                    .tint(progress == 1.0 ? .green : Color.brandPrimary)

                Text("\(completedCount) of \(total) completed")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Category Sections

    private func sortedCategories(_ checklist: FilingChecklist) -> [FilingRequirement.FilingCategory] {
        checklist.byCategory.keys.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func categorySection(_ category: FilingRequirement.FilingCategory, checklist: FilingChecklist) -> some View {
        let items = checklist.byCategory[category] ?? []

        return VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack(spacing: 6) {
                Image(systemName: categoryIcon(category))
                    .font(.caption)
                    .foregroundStyle(categoryColor(category))
                    .accessibilityHidden(true)

                Text(category.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 6) {
                ForEach(items) { item in
                    filingRow(item)
                }
            }
        }
    }

    private func filingRow(_ item: FilingRequirement) -> some View {
        let isCompleted = completedIDs.contains(item.id)

        return Button {
            withAnimation(FLOAnimation.quick) {
                if isCompleted {
                    completedIDs.remove(item.id)
                } else {
                    completedIDs.insert(item.id)
                    HapticService.play(.light)
                }
            }
        } label: {
            HStack(spacing: 12) {
                // Checkbox
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isCompleted ? .green : .secondary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.formName)
                            .font(.subheadline.weight(.medium))
                            .strikethrough(isCompleted)
                            .foregroundStyle(isCompleted ? .secondary : .primary)

                        if let entity = item.entityName {
                            Text(entity)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.brandPrimary.opacity(0.12))
                                .clipShape(Capsule())
                                .foregroundStyle(Color.brandPrimary)
                        }
                    }

                    Text(item.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        priorityBadge(item.priority)

                        Text(item.dueDateDescription)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .background(isCompleted ? Color.green.opacity(0.05) : Color.floSecondarySystemBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.formName), \(item.description), \(item.dueDateDescription), \(isCompleted ? "completed" : "not completed")")
        .accessibilityAddTraits(isCompleted ? .isSelected : [])
    }

    private func priorityBadge(_ priority: FilingRequirement.FilingPriority) -> some View {
        let color: Color = switch priority {
        case .critical: .red
        case .upcoming: .orange
        case .future: .green
        }

        return Text(priority.displayName)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func categoryIcon(_ category: FilingRequirement.FilingCategory) -> String {
        switch category {
        case .federalBusiness: return "building.columns.fill"
        case .federalPersonal: return "person.crop.rectangle.fill"
        case .state:           return "flag.fill"
        case .informational:   return "info.circle.fill"
        case .estimated:       return "calendar.badge.clock"
        }
    }

    private func categoryColor(_ category: FilingRequirement.FilingCategory) -> Color {
        switch category {
        case .federalBusiness: return .blue
        case .federalPersonal: return .indigo
        case .state:           return .green
        case .informational:   return .orange
        case .estimated:       return .teal
        }
    }

    // MARK: - Disclaimer

    private var disclaimerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                Text("Important")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.orange)
            }

            Text("This checklist is generated from your FLO data and may not cover all filing requirements. State deadlines vary. Consult your tax professional for complete filing guidance.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.orange.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Data

    private func generateChecklist() {
        checklist = FilingChecklistService.shared.generateChecklist(
            taxYear: selectedYear,
            businesses: businesses,
            taxSettings: taxSettings
        )
    }
}

#if DEBUG
#Preview("Filing Checklist") {
    NavigationStack {
        FilingChecklistView()
            .modelContainer(for: [BusinessProfile.self, TaxSettings.self])
    }
}
#endif
