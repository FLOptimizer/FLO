//  CarryforwardRegisterView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — Tax carryforward register
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Full-page view for managing carryforward items: suspended losses,
//  NOL carryforwards, remaining depreciation, amortization, and more.
//

import SwiftUI
import FLODesignSystem
import SwiftData

struct CarryforwardRegisterView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<BusinessProfile> { $0.isActive },
        sort: \BusinessProfile.sortOrder
    )
    private var businesses: [BusinessProfile]

    @State private var showingAddItem = false
    @State private var selectedBusiness: BusinessProfile?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ProfileHeaderCard(
                    icon: "arrow.uturn.forward.circle.fill",
                    title: "Carryforward Register",
                    subtitle: "Track items affecting future tax years",
                    color: .orange
                )

                if businesses.count > 1 {
                    businessPicker
                }

                let items = filteredItems
                if items.isEmpty {
                    emptyState
                } else {
                    activeSection(items.filter { $0.isActive })
                    completedSection(items.filter { !$0.isActive })
                }
            }
            .padding(16)
        }
        .navigationTitle("Carryforwards")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddItem = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddCarryforwardView(business: selectedBusiness ?? businesses.first)
        }
    }

    private var filteredItems: [TaxCarryforward] {
        if let business = selectedBusiness {
            return business.carryforwards ?? []
        }
        return businesses.flatMap { $0.carryforwards ?? [] }
    }

    // MARK: - Business Picker

    private var businessPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    selectedBusiness = nil
                } label: {
                    Text("All")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedBusiness == nil ? Color.orange.opacity(0.15) : Color.clear)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(selectedBusiness == nil ? Color.orange : Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

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
                        .background(selectedBusiness?.id == business.id ? Color.orange.opacity(0.15) : Color.clear)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(selectedBusiness?.id == business.id ? Color.orange : Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Sections

    private func activeSection(_ items: [TaxCarryforward]) -> some View {
        Group {
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Active Carryforwards")
                        .font(.headline)
                    ForEach(items.sorted(by: { $0.originYear < $1.originYear })) { item in
                        carryforwardRow(item)
                    }
                }
            }
        }
    }

    private func completedSection(_ items: [TaxCarryforward]) -> some View {
        Group {
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Completed")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    ForEach(items.sorted(by: { $0.originYear > $1.originYear })) { item in
                        carryforwardRow(item)
                            .opacity(0.6)
                    }
                }
            }
        }
    }

    private func carryforwardRow(_ item: TaxCarryforward) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: item.type.icon)
                    .foregroundStyle(item.type.color)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.type.displayName)
                        .font(.subheadline.weight(.semibold))
                    HStack(spacing: 8) {
                        if let partner = item.partnerName {
                            Text(partner)
                        }
                        Text("Origin: \(String(item.originYear))")
                        if let exp = item.expirationYear {
                            Text("Expires: \(String(exp))")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(item.remainingAmount.asCurrency)
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(item.status.color)
                    Text(item.status.displayName)
                        .font(.caption2)
                        .foregroundStyle(item.status.color)
                }
            }

            if item.amountUtilized > 0 {
                ProgressView(value: item.utilizationPercentage)
                    .tint(item.status.color)
                HStack {
                    Text("Original: \(item.originalAmount.asCurrency)")
                    Spacer()
                    Text("Used: \(item.amountUtilized.asCurrency)")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }

            if let notes = item.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }

            // IRC reference
            if !item.type.ircReference.isEmpty {
                Text(item.type.ircReference)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.uturn.forward.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Carryforward Items")
                .font(.headline)
            Text("Track suspended losses, NOL carryforwards, remaining depreciation, and other items that affect future tax years.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Add Item") {
                showingAddItem = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding(32)
    }
}

// MARK: - Add Carryforward View

struct AddCarryforwardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let business: BusinessProfile?

    @State private var type: CarryforwardType = .suspendedLoss704d
    @State private var originYear = String(Calendar.current.component(.year, from: Date()))
    @State private var originalAmount = ""
    @State private var notes = ""
    @State private var partnerName = ""
    @State private var hasExpiration = false
    @State private var expirationYear = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Carryforward Type", selection: $type) {
                        ForEach(CarryforwardType.allCases) { t in
                            Label(t.displayName, systemImage: t.icon).tag(t)
                        }
                    }
                    Text(type.explanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Details") {
                    TextField("Origin Year", text: $originYear)
                        #if !os(macOS)
                        .keyboardType(.numberPad)
                        #endif
                    TextField("Amount", text: $originalAmount)
                        #if !os(macOS)
                        .keyboardType(.decimalPad)
                        #endif
                    TextField("Partner Name (optional)", text: $partnerName)
                    Toggle("Has Expiration", isOn: $hasExpiration)
                    if hasExpiration {
                        TextField("Expiration Year", text: $expirationYear)
                            #if !os(macOS)
                            .keyboardType(.numberPad)
                            #endif
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
            }
            .navigationTitle("Add Carryforward")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveItem() }
                        .disabled(Double(originalAmount) == nil || Int(originYear) == nil)
                }
            }
        }
    }

    private func saveItem() {
        guard let amount = Double(originalAmount), let year = Int(originYear) else { return }

        let item = TaxCarryforward(
            type: type,
            originYear: year,
            originalAmount: amount,
            expirationYear: hasExpiration ? Int(expirationYear) : nil,
            notes: notes.isEmpty ? nil : notes,
            partnerName: partnerName.isEmpty ? nil : partnerName,
            businessProfile: business
        )

        modelContext.insert(item)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        CarryforwardRegisterView()
            .modelContainer(ModelContainer.preview())
    }
}
