//  JurisdictionManagementView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — Manual jurisdiction tagging for business entities
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Lets users tag their businesses with filing jurisdictions (state, county, city).
//  Phase 2 v1: manual entry. Phase 3 will add auto-detection from address.
//

import SwiftUI
import FLODesignSystem
import SwiftData

struct JurisdictionManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(
        filter: #Predicate<BusinessProfile> { $0.isActive },
        sort: \BusinessProfile.sortOrder
    )
    private var businesses: [BusinessProfile]

    @State private var showingAddSheet = false
    @State private var selectedBusiness: BusinessProfile?
    @State private var viewAppeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard

                if businesses.isEmpty {
                    emptyState
                } else {
                    ForEach(businesses) { business in
                        businessJurisdictionCard(business)
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Jurisdictions")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            if let business = selectedBusiness {
                NavigationStack {
                    AddJurisdictionView(business: business)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                viewAppeared = true
            }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        ProfileHeaderCard(
            icon: "map.fill",
            title: "Filing Jurisdictions",
            subtitle: "Track state, county, and city filing requirements",
            color: .green
        )
    }

    // MARK: - Business Card

    private func businessJurisdictionCard(_ business: BusinessProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: business.displayIcon)
                    .foregroundStyle(Color.brandPrimary)
                    .accessibilityHidden(true)
                Text(business.businessName)
                    .font(.headline)
                Spacer()
                Button {
                    selectedBusiness = business
                    showingAddSheet = true
                    HapticService.play(.light)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.brandPrimary)
                }
            }

            let jurisdictions = business.activeJurisdictions
            if jurisdictions.isEmpty {
                HStack {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text("No jurisdictions configured")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } else {
                ForEach(jurisdictions) { jurisdiction in
                    jurisdictionRow(jurisdiction, business: business)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func jurisdictionRow(_ jurisdiction: EntityJurisdiction, business: BusinessProfile) -> some View {
        HStack(spacing: 10) {
            Image(systemName: jurisdiction.level.icon)
                .font(.caption)
                .foregroundStyle(levelColor(jurisdiction.level))
                .frame(width: 20)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(jurisdiction.displayName)
                        .font(.subheadline.weight(.medium))

                    Text(jurisdiction.level.displayName)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(levelColor(jurisdiction.level).opacity(0.15))
                        .foregroundStyle(levelColor(jurisdiction.level))
                        .clipShape(Capsule())
                }

                Text(jurisdiction.filingDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Delete
            Button {
                withAnimation(FLOAnimation.quick) {
                    jurisdiction.isActive = false
                    try? modelContext.save()
                }
                HapticService.play(.light)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(Color.floSecondarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func levelColor(_ level: JurisdictionLevel) -> Color {
        switch level {
        case .state:  return .blue
        case .county: return .orange
        case .city:   return .green
        case .local:  return .purple
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "building.2")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.quaternary)
                .accessibilityHidden(true)
            Text("No businesses configured")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(30)
    }
}

// MARK: - Add Jurisdiction View

struct AddJurisdictionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let business: BusinessProfile

    @State private var level: JurisdictionLevel = .state
    @State private var name: String = ""
    @State private var stateCode: String = ""
    @State private var taxType: JurisdictionTaxType = .income
    @State private var requiresFiling = true
    @State private var deadlineDescription: String = ""
    @State private var formName: String = ""
    @State private var notes: String = ""

    private var canSave: Bool {
        !name.isEmpty && !stateCode.isEmpty
    }

    var body: some View {
        Form {
            Section("Jurisdiction") {
                Picker("Level", selection: $level) {
                    ForEach(JurisdictionLevel.allCases, id: \.self) { lvl in
                        Label(lvl.displayName, systemImage: lvl.icon)
                            .tag(lvl)
                    }
                }

                TextField("Name (e.g., Kentucky, Fayette County)", text: $name)

                Picker("State", selection: $stateCode) {
                    Text("Select...").tag("")
                    ForEach(Array(FilingChecklistService.stateAbbreviationToName.sorted(by: { $0.value < $1.value })), id: \.key) { code, stateName in
                        Text("\(stateName) (\(code))").tag(code)
                    }
                }
            }

            Section("Filing Details") {
                Picker("Tax Type", selection: $taxType) {
                    ForEach(JurisdictionTaxType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }

                Toggle("Requires Filing", isOn: $requiresFiling)

                TextField("Filing Deadline (e.g., April 15)", text: $deadlineDescription)
                TextField("Form Name/Number", text: $formName)
            }

            Section("Notes") {
                TextField("Optional notes", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
        .navigationTitle("Add Jurisdiction")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(!canSave)
            }
        }
        .onAppear {
            // Pre-fill state from business profile
            if let businessState = business.state, !businessState.isEmpty {
                stateCode = businessState
                if level == .state {
                    name = FilingChecklistService.stateAbbreviationToName[businessState] ?? businessState
                }
            }
        }
    }

    private func save() {
        let jurisdiction = EntityJurisdiction(
            level: level,
            name: name,
            stateCode: stateCode,
            requiresFiling: requiresFiling,
            taxType: taxType,
            deadlineDescription: deadlineDescription.isEmpty ? nil : deadlineDescription,
            formName: formName.isEmpty ? nil : formName,
            notes: notes.isEmpty ? nil : notes
        )
        jurisdiction.businessProfile = business
        modelContext.insert(jurisdiction)

        do {
            try modelContext.save()
            HapticService.play(.success)
            dismiss()
        } catch {
            print("Failed to save jurisdiction: \(error)")
        }
    }
}

#if DEBUG
#Preview("Jurisdiction Management") {
    NavigationStack {
        JurisdictionManagementView()
            .modelContainer(for: [BusinessProfile.self, EntityJurisdiction.self])
    }
}
#endif
