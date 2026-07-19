//  PreparerChecklistView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — CPA preparation checklist with shareable output
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Generates a "what your preparer needs" checklist based on user entities.
//  Supports sharing as plain text for sending to CPA/tax preparer.
//

import SwiftUI
import FLODesignSystem
import SwiftData

struct PreparerChecklistView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(
        filter: #Predicate<BusinessProfile> { $0.isActive },
        sort: \BusinessProfile.sortOrder
    )
    private var businesses: [BusinessProfile]

    @Query private var allTransactions: [Transaction]
    @Query private var taxSettingsAll: [TaxSettings]

    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date()) - 1
    @State private var checklist: PreparerChecklist?
    @State private var completedIDs: Set<UUID> = []
    @State private var showingShareSheet = false
    @State private var shareText = ""
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
                    entityOverview(checklist)
                    progressCard(checklist)

                    ForEach(checklist.sections) { section in
                        sectionCard(section)
                    }

                    shareButton
                } else {
                    ProgressView("Generating checklist...")
                        .padding(40)
                }
            }
            .padding()
        }

        .navigationTitle("Preparer Checklist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .shareSheet(isPresented: $showingShareSheet, items: [shareText])
        .onAppear {
            refreshChecklist()
            withAnimation(.easeOut(duration: 0.3)) { viewAppeared = true }
        }
        .onChange(of: selectedYear) { _, _ in refreshChecklist() }
    }

    // MARK: - Header

    private var headerCard: some View {
        ProfileHeaderCard(
            icon: "person.badge.shield.checkmark.fill",
            title: "Preparer Checklist",
            subtitle: "What your CPA needs for \(selectedYear) filing",
            color: .indigo
        )
    }

    // MARK: - Year Picker

    private var yearPicker: some View {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Picker("Tax Year", selection: $selectedYear) {
            ForEach((currentYear - 3)...(currentYear - 1), id: \.self) { year in
                Text(String(year)).tag(year)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 4)
    }

    // MARK: - Entity Overview

    private func entityOverview(_ checklist: PreparerChecklist) -> some View {
        Group {
            if !checklist.entitySummaries.isEmpty {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(checklist.entitySummaries) { entity in
                            entityRow(entity)
                        }
                    }
                } label: {
                    Label("Your Entities", systemImage: "building.2.fill")
                        .font(.headline)
                }
            }
        }
    }

    private func entityRow(_ entity: EntityPreparerSummary) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entity.businessName)
                    .font(.subheadline.bold())
                Text("\(entity.businessType) — \(entity.formRequired)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 6) {
                if entity.hasPartners {
                    metaBadge("\(entity.partnerCount) partners", icon: "person.2")
                }
                if entity.hasAssets {
                    metaBadge("\(entity.assetCount) assets", icon: "building")
                }
            }
        }
    }

    private func metaBadge(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.gray.opacity(0.15))
            .clipShape(Capsule())
    }

    // MARK: - Progress

    private func progressCard(_ checklist: PreparerChecklist) -> some View {
        let total = checklist.totalItems
        let completed = completedIDs.count
        let progress = total > 0 ? Double(completed) / Double(total) : 0

        return GroupBox {
            VStack(spacing: 8) {
                HStack {
                    Text("\(completed) of \(total) items gathered")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.brandPrimary)
                }

                ProgressView(value: progress)
                    .tint(Color.brandPrimary)
            }
        }
    }

    // MARK: - Section Card

    private func sectionCard(_ section: PreparerSection) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(section.items) { item in
                    itemRow(item)
                }

                if let notes = section.notes {
                    Divider()
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } label: {
            Label(section.title, systemImage: section.icon)
                .font(.headline)
        }
    }

    private func itemRow(_ item: PreparerItem) -> some View {
        let isChecked = item.isProvided || completedIDs.contains(item.id)

        return Button {
            if !item.isProvided {
                if completedIDs.contains(item.id) {
                    completedIDs.remove(item.id)
                } else {
                    completedIDs.insert(item.id)
                    HapticService.play(.light)
                }
            }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isChecked ? .green : .secondary)
                    .font(.body)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.label)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .strikethrough(isChecked && !item.isProvided)

                    if let detail = item.detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let source = item.source {
                        Label(source, systemImage: "checkmark.seal")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }

                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Share

    private var shareButton: some View {
        Button {
            guard let checklist else { return }
            shareText = PreparerChecklistService.shared.generateShareableText(checklist: checklist)
            showingShareSheet = true
        } label: {
            Label("Share with Preparer", systemImage: "square.and.arrow.up")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.brandPrimary)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Helpers

    private func refreshChecklist() {
        checklist = PreparerChecklistService.shared.generateChecklist(
            businesses: businesses,
            transactions: allTransactions,
            taxSettings: taxSettings,
            taxYear: selectedYear
        )
        completedIDs = []
    }
}
