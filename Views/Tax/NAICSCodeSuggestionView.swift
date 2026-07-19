//  NAICSCodeSuggestionView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — Auto-suggest NAICS codes from spending patterns
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Analyzes transaction spending categories to suggest likely NAICS codes,
//  and provides a curated list for manual selection by business type.
//

import SwiftUI
import FLODesignSystem
import SwiftData

struct NAICSCodeSuggestionView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(
        filter: #Predicate<BusinessProfile> { $0.isActive },
        sort: \BusinessProfile.sortOrder
    )
    private var businesses: [BusinessProfile]

    @Query private var allTransactions: [Transaction]

    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @State private var selectedBusiness: BusinessProfile?
    @State private var suggestions: [NAICSSuggestion] = []
    @State private var showingCommonCodes = false
    @State private var viewAppeared = false

    private var hasProAccess: Bool {
        subscriptionManager.currentTier == .pro
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                businessPicker

                if selectedBusiness != nil {
                    if !suggestions.isEmpty {
                        suggestionsSection
                    } else {
                        noSuggestionsCard
                    }
                }

                if let biz = selectedBusiness {
                    commonCodesSection(biz)
                }

                disclaimerCard
            }
            .padding()
        }

        .navigationTitle("NAICS Codes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .onAppear {
            if selectedBusiness == nil {
                selectedBusiness = businesses.first
            }
            refreshSuggestions()
            withAnimation(.easeOut(duration: 0.3)) { viewAppeared = true }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        ProfileHeaderCard(
            icon: "number.circle.fill",
            title: "NAICS Code Finder",
            subtitle: "Auto-suggested from your spending patterns",
            color: .teal
        )
    }

    // MARK: - Business Picker

    private var businessPicker: some View {
        Group {
            if businesses.count > 1 {
                Picker("Business", selection: $selectedBusiness) {
                    ForEach(businesses) { biz in
                        Text(biz.businessName).tag(Optional(biz))
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 4)
                .onChange(of: selectedBusiness) { _, _ in refreshSuggestions() }
            }
        }
    }

    // MARK: - Suggestions

    private var suggestionsSection: some View {
        GroupBox {
            VStack(spacing: 10) {
                ForEach(suggestions) { suggestion in
                    suggestionRow(suggestion)
                }
            }
        } label: {
            Label("Suggested Codes", systemImage: "sparkles")
                .font(.headline)
        }
    }

    private func suggestionRow(_ suggestion: NAICSSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(suggestion.code)
                    .font(.subheadline.bold().monospacedDigit())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.brandPrimary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 1) {
                    Text(suggestion.title)
                        .font(.subheadline.bold())
                    Text(suggestion.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                confidenceBadge(suggestion.confidence)
            }

            if !suggestion.matchedCategories.isEmpty {
                HStack(spacing: 4) {
                    Text("Matched:")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    ForEach(suggestion.matchedCategories.prefix(3), id: \.self) { cat in
                        Text(cat)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }

            if suggestion.id != suggestions.last?.id {
                Divider()
            }
        }
        .padding(.vertical, 2)
    }

    private func confidenceBadge(_ confidence: Double) -> some View {
        let pct = Int(confidence * 100)
        let color: Color = confidence >= 0.6 ? .green : confidence >= 0.3 ? .orange : .gray
        return Text("\(pct)%")
            .font(.caption.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    // MARK: - No Suggestions

    private var noSuggestionsCard: some View {
        GroupBox {
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("No strong matches found")
                    .font(.subheadline.bold())
                Text("Add more categorized business transactions to improve suggestions, or browse common codes below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Common Codes

    private func commonCodesSection(_ business: BusinessProfile) -> some View {
        let codes = NAICSCodeSuggestionService.shared.commonCodes(for: business.businessType)

        return GroupBox {
            LazyVStack(spacing: 8) {
                ForEach(codes) { code in
                    commonCodeRow(code, business: business)
                }
            }
        } label: {
            HStack {
                Label("Common Codes for \(business.businessType.displayName)", systemImage: "list.bullet")
                    .font(.headline)
                Spacer()
                Text("\(codes.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func commonCodeRow(_ code: NAICSSuggestion, business: BusinessProfile) -> some View {
        Button {
            applyCode(code, to: business)
        } label: {
            HStack {
                Text(code.code)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Color.brandPrimary)

                VStack(alignment: .leading, spacing: 1) {
                    Text(code.title)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Text(code.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if business.naicsCode == code.code {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Disclaimer

    private var disclaimerCard: some View {
        GroupBox {
            Text("NAICS codes are used on tax returns (Schedule C Line B, Form 1065). Suggestions are based on spending patterns and may not reflect your primary business activity. Confirm with your tax preparer.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Actions

    private func applyCode(_ code: NAICSSuggestion, to business: BusinessProfile) {
        business.naicsCode = code.code
        HapticService.play(.medium)
    }

    private func refreshSuggestions() {
        guard let biz = selectedBusiness else {
            suggestions = []
            return
        }

        suggestions = NAICSCodeSuggestionService.shared.suggestCodes(
            transactions: allTransactions,
            businessType: biz.businessType
        )
    }
}
