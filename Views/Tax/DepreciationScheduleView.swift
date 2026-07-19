//  DepreciationScheduleView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — Asset depreciation management and schedule viewing
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Full-page view for managing depreciable assets: add/edit/view assets with
//  their MACRS depreciation schedules. Shows current-year and accumulated
//  depreciation for each asset.
//

import SwiftUI
import FLODesignSystem
import SwiftData

struct DepreciationScheduleView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<BusinessProfile> { $0.isActive },
        sort: \BusinessProfile.sortOrder
    )
    private var businesses: [BusinessProfile]

    @State private var selectedBusiness: BusinessProfile?
    @State private var showingAddAsset = false
    @State private var expandedAssetID: UUID?
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ProfileHeaderCard(
                    icon: "chart.bar.fill",
                    title: "Depreciation Schedules",
                    subtitle: "Track assets and MACRS depreciation",
                    color: .teal
                )

                if businesses.count > 1 {
                    businessPicker
                }

                yearPicker

                if let business = effectiveBusiness {
                    let assets = business.activeAssets
                    if assets.isEmpty {
                        emptyState
                    } else {
                        summaryCard(assets: assets)
                        assetList(assets: assets)
                    }
                } else {
                    emptyState
                }
            }
            .padding(16)
        }
        .navigationTitle("Depreciation")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddAsset = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddAsset) {
            AddAssetView(business: effectiveBusiness)
        }
        .onAppear {
            selectedBusiness = businesses.first
        }
    }

    private var effectiveBusiness: BusinessProfile? {
        selectedBusiness ?? businesses.first
    }

    // MARK: - Business Picker

    private var businessPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(businesses) { business in
                    Button {
                        selectedBusiness = business
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: business.displayIcon)
                                .font(.caption)
                            Text(business.businessName)
                                .font(.caption.weight(.medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedBusiness?.id == business.id ? Color.teal.opacity(0.15) : Color.clear)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(selectedBusiness?.id == business.id ? Color.teal : Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Year Picker

    private var yearPicker: some View {
        HStack {
            Text("Tax Year")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Picker("Year", selection: $selectedYear) {
                let currentYear = Calendar.current.component(.year, from: Date())
                ForEach((currentYear - 2)...(currentYear + 2), id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 300)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Summary

    private func summaryCard(assets: [DepreciableAsset]) -> some View {
        let totalCost = assets.reduce(0) { $0 + $1.cost }
        let yearDepreciation = MACRSCalculationService.shared.totalDepreciationForYear(selectedYear, assets: assets)
        let totalAccumulated = assets.reduce(0) { $0 + $1.accumulatedDepreciation(throughYear: selectedYear) }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sum")
                    .foregroundStyle(.teal)
                Text("Summary — \(String(selectedYear))")
                    .font(.headline)
            }
            Divider()
            TaxSummaryRow(label: "Total Asset Cost", amount: totalCost, color: .primary)
            TaxSummaryRow(label: "\(String(selectedYear)) Depreciation", amount: yearDepreciation, color: .teal)
            TaxSummaryRow(label: "Accumulated Depreciation", amount: totalAccumulated, color: .secondary)
            TaxSummaryRow(label: "Net Book Value", amount: totalCost - totalAccumulated, color: .blue, isTotal: true)
            Text("\(assets.count) active asset\(assets.count == 1 ? "" : "s")")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Asset List

    private func assetList(assets: [DepreciableAsset]) -> some View {
        ForEach(assets) { asset in
            assetCard(asset)
        }
    }

    private func assetCard(_ asset: DepreciableAsset) -> some View {
        let yearDepr = asset.depreciationForYear(selectedYear)
        let nbv = asset.netBookValue(atEndOfYear: selectedYear)
        let isExpanded = expandedAssetID == asset.id

        return VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedAssetID = isExpanded ? nil : asset.id
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(asset.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        HStack(spacing: 8) {
                            Text(asset.propertyClass.displayName)
                            Text(asset.depreciationMethod.shortName)
                            Text(asset.convention.displayName)
                        }
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(yearDepr.asCurrency)
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.teal)
                        Text("NBV \(nbv.asCurrency)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()

                // Asset details
                VStack(alignment: .leading, spacing: 6) {
                    detailRow("Cost Basis", value: asset.cost.asCurrency)
                    detailRow("Placed in Service", value: asset.placedInServiceDate.formatted(date: .abbreviated, time: .omitted))
                    if let sn = asset.serialNumber, !sn.isEmpty {
                        detailRow("Serial Number", value: sn)
                    }
                    if let s179 = asset.section179Amount, s179 > 0 {
                        detailRow("Section 179", value: s179.asCurrency)
                    }
                    if let bonus = asset.bonusDepreciationPercent, bonus > 0 {
                        detailRow("Bonus Depreciation", value: "\(Int(bonus * 100))%")
                    }
                }

                Divider()

                // Yearly schedule
                Text("Depreciation Schedule")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                let schedule = asset.fullSchedule()
                ForEach(schedule) { entry in
                    HStack {
                        Text(String(entry.year))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(entry.year == selectedYear ? .teal : .secondary)
                            .frame(width: 40, alignment: .leading)
                        Text(entry.amount.asCurrency)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(entry.year == selectedYear ? .primary : .secondary)
                        Spacer()
                        Text("Rem: \(entry.remainingBasis.asCurrency)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 1)
                    .background(entry.year == selectedYear ? Color.teal.opacity(0.05) : Color.clear)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit())
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Depreciable Assets")
                .font(.headline)
            Text("Add equipment, vehicles, or property to track depreciation schedules.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Add Asset") {
                showingAddAsset = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
        }
        .padding(32)
    }
}

// MARK: - Add Asset View

struct AddAssetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let business: BusinessProfile?

    @State private var name = ""
    @State private var cost = ""
    @State private var placedInServiceDate = Date()
    @State private var propertyClass: PropertyClass = .fiveYear
    @State private var depreciationMethod: DepreciationMethod = .macrs200DB
    @State private var convention: DepreciationConvention = .halfYear
    @State private var serialNumber = ""
    @State private var assetDescription = ""
    @State private var section179Amount = ""
    @State private var bonusPercent = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Asset Details") {
                    TextField("Asset Name", text: $name)
                    TextField("Cost Basis", text: $cost)
                        #if !os(macOS)
                        .keyboardType(.decimalPad)
                        #endif
                    DatePicker("Placed in Service", selection: $placedInServiceDate, displayedComponents: .date)
                    TextField("Serial Number (optional)", text: $serialNumber)
                    TextField("Description (optional)", text: $assetDescription)
                }

                Section("Depreciation Method") {
                    Picker("Property Class", selection: $propertyClass) {
                        ForEach(PropertyClass.allCases) { pc in
                            Text(pc.displayName).tag(pc)
                        }
                    }
                    Picker("Method", selection: $depreciationMethod) {
                        ForEach(DepreciationMethod.allCases) { method in
                            Text(method.displayName).tag(method)
                        }
                    }
                    Picker("Convention", selection: $convention) {
                        ForEach(DepreciationConvention.allCases) { conv in
                            Text(conv.displayName).tag(conv)
                        }
                    }
                }

                Section("Special Elections (Optional)") {
                    TextField("Section 179 Amount", text: $section179Amount)
                        #if !os(macOS)
                        .keyboardType(.decimalPad)
                        #endif
                    TextField("Bonus Depreciation % (e.g., 40)", text: $bonusPercent)
                        #if !os(macOS)
                        .keyboardType(.decimalPad)
                        #endif
                }

                if !name.isEmpty, let costValue = Double(cost), costValue > 0 {
                    Section("Preview") {
                        let previewAsset = DepreciableAsset(
                            name: name,
                            cost: costValue,
                            placedInServiceDate: placedInServiceDate,
                            propertyClass: propertyClass,
                            depreciationMethod: depreciationMethod,
                            convention: convention,
                            section179Amount: Double(section179Amount),
                            bonusDepreciationPercent: Double(bonusPercent).map { $0 / 100.0 }
                        )
                        let schedule = previewAsset.fullSchedule()
                        ForEach(schedule.prefix(6)) { entry in
                            HStack {
                                Text(String(entry.year))
                                    .font(.caption.monospacedDigit())
                                Spacer()
                                Text(entry.amount.asCurrency)
                                    .font(.caption.monospacedDigit())
                            }
                        }
                        if schedule.count > 6 {
                            Text("+ \(schedule.count - 6) more years")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .navigationTitle("Add Asset")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAsset() }
                        .disabled(name.isEmpty || Double(cost) == nil)
                }
            }
        }
    }

    private func saveAsset() {
        guard let costValue = Double(cost), costValue > 0 else { return }

        let asset = DepreciableAsset(
            name: name,
            cost: costValue,
            placedInServiceDate: placedInServiceDate,
            propertyClass: propertyClass,
            depreciationMethod: depreciationMethod,
            convention: convention,
            section179Amount: Double(section179Amount),
            bonusDepreciationPercent: Double(bonusPercent).map { $0 / 100.0 },
            serialNumber: serialNumber.isEmpty ? nil : serialNumber,
            assetDescription: assetDescription.isEmpty ? nil : assetDescription,
            businessProfile: business
        )

        modelContext.insert(asset)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        DepreciationScheduleView()
            .modelContainer(ModelContainer.preview())
    }
}
