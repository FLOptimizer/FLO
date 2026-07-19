//  BusinessTaxSummaryView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.0 - Per-Business Tax Summary with form line breakdown, K-1, depreciation
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Shows tax position for each business with combined impact.
//  Designed for tax season review — separate Schedule C/F/E per entity.
//

import SwiftUI
import FLODesignSystem
import SwiftData

struct BusinessTaxSummaryView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<BusinessProfile> { $0.isActive },
        sort: \BusinessProfile.sortOrder
    )
    private var businesses: [BusinessProfile]

    @State private var allTransactions: [Transaction] = []
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var viewAppeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                yearPicker
                if businesses.isEmpty {
                    emptyState
                } else {
                    businessCards
                    combinedImpactCard
                }
            }
            .padding(16)
        }
        .navigationTitle("Tax Summary")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            loadTransactions()
            withAnimation(.easeOut(duration: 0.3)) {
                viewAppeared = true
            }
        }
        .onChange(of: selectedYear) { _, _ in
            loadTransactions()
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        ProfileHeaderCard(
            icon: "chart.bar.doc.horizontal.fill",
            title: "Tax Summary — \(String(selectedYear))",
            subtitle: "Per-business breakdown for tax filing",
            color: .orange
        )
        .opacity(viewAppeared ? 1 : 0)
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
                ForEach((currentYear - 2)...(currentYear), id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 240)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Per-Business Cards

    private var businessCards: some View {
        ForEach(Array(businesses.enumerated()), id: \.element.id) { index, business in
            VStack(spacing: 12) {
                BusinessTaxCard(
                    business: business,
                    summary: summaryFor(business),
                    ytdContributions: contributionsFor(business),
                    ytdDraws: drawsFor(business)
                )

                // Form Line Breakdown (expandable)
                FormLineBreakdownCard(
                    business: business,
                    transactions: allTransactions,
                    year: selectedYear
                )

                // Partner Allocations (for partnerships/LLCs)
                if business.isPartnership && !(business.partners ?? []).isEmpty {
                    PartnerAllocationsCard(
                        business: business,
                        transactions: allTransactions,
                        year: selectedYear
                    )
                }

                // Depreciation Summary (if assets exist)
                if !(business.assets ?? []).isEmpty {
                    DepreciationSummaryCard(
                        business: business,
                        year: selectedYear
                    )
                }

                // Active Carryforwards
                if !(business.carryforwards ?? []).filter({ $0.isActive }).isEmpty {
                    CarryforwardSummaryCard(business: business)
                }
            }
            .opacity(viewAppeared ? 1 : 0)
            .offset(y: viewAppeared ? 0 : 20)
            .animation(.easeOut(duration: 0.3).delay(Double(index) * 0.1 + 0.1), value: viewAppeared)
        }
    }

    // MARK: - Combined Impact

    private var combinedImpactCard: some View {
        let summaries = businesses.map { summaryFor($0) }
        let totalIncome = summaries.reduce(0.0) { $0 + $1.grossIncome }
        let totalExpenses = summaries.reduce(0.0) { $0 + $1.totalExpenses }
        let totalNet = totalIncome - totalExpenses

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.triangle.merge")
                    .font(.title3)
                    .foregroundStyle(.blue)
                Text("Combined Impact")
                    .font(.headline)
            }

            Divider()

            TaxSummaryRow(label: "Total Business Revenue", amount: totalIncome, color: .green)
            TaxSummaryRow(label: "Total Business Expenses", amount: -totalExpenses, color: .red)

            Divider()

            TaxSummaryRow(
                label: totalNet >= 0 ? "Combined Net Profit" : "Combined Net Loss",
                amount: totalNet,
                color: totalNet >= 0 ? .green : .orange,
                isTotal: true
            )

            if totalNet < 0 {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Net loss may offset other income on your personal return")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .opacity(viewAppeared ? 1 : 0)
        .animation(.easeOut(duration: 0.3).delay(0.4), value: viewAppeared)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "building.2.crop.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Businesses Set Up")
                .font(.headline)
            Text("Add a business in Settings to see per-business tax summaries.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }

    // MARK: - Data Loading

    private func loadTransactions() {
        let calendar = Calendar.current
        let startOfYear = calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1))!
        let endOfYear = calendar.date(from: DateComponents(year: selectedYear, month: 12, day: 31, hour: 23, minute: 59, second: 59))!

        var descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> {
                $0.date >= startOfYear && $0.date <= endOfYear && !$0.isTransfer
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        allTransactions = (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Summaries

    private func summaryFor(_ business: BusinessProfile) -> TaxCalculationService.BusinessFinancialSummary {
        TaxCalculationService.shared.businessSummaries(
            businesses: [business],
            allTransactions: allTransactions
        ).first ?? TaxCalculationService.BusinessFinancialSummary(
            business: business, grossIncome: 0, totalExpenses: 0, netIncome: 0, transactionCount: 0
        )
    }

    private func contributionsFor(_ business: BusinessProfile) -> Double {
        let contributions = allTransactions.filter { _ in false } // Contributions are transfers, not transactions
        // Use transfer data instead
        let descriptor = FetchDescriptor<Transfer>(
            predicate: #Predicate<Transfer> {
                $0.transferTypeRaw == "capitalContribution"
            }
        )
        guard let transfers = try? modelContext.fetch(descriptor) else { return 0 }
        let calendar = Calendar.current
        return transfers.filter {
            calendar.component(.year, from: $0.date) == selectedYear &&
            $0.toAccount?.businessProfile?.id == business.id
        }.reduce(0) { $0 + $1.amount }
    }

    private func drawsFor(_ business: BusinessProfile) -> Double {
        let descriptor = FetchDescriptor<Transfer>(
            predicate: #Predicate<Transfer> {
                $0.transferTypeRaw == "ownersDraw"
            }
        )
        guard let transfers = try? modelContext.fetch(descriptor) else { return 0 }
        let calendar = Calendar.current
        return transfers.filter {
            calendar.component(.year, from: $0.date) == selectedYear &&
            $0.fromAccount?.businessProfile?.id == business.id
        }.reduce(0) { $0 + $1.amount }
    }
}

// MARK: - Business Tax Card

struct BusinessTaxCard: View {
    let business: BusinessProfile
    let summary: TaxCalculationService.BusinessFinancialSummary
    let ytdContributions: Double
    let ytdDraws: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: business.displayIcon)
                    .font(.title2)
                    .foregroundStyle(business.isPrimary ? .blue : .secondary)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(business.businessName)
                        .font(.headline)
                    Text("\(business.businessType.displayName) — \(business.businessType.taxFormName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            // Revenue & Expenses
            TaxSummaryRow(label: "Revenue", amount: summary.grossIncome, color: .green)
            TaxSummaryRow(label: "Expenses", amount: -summary.totalExpenses, color: .red)

            // Capital flows (if any)
            if ytdContributions > 0 {
                TaxSummaryRow(label: "Capital Contributions", amount: ytdContributions, color: .blue)
                    .opacity(0.8)
            }
            if ytdDraws > 0 {
                TaxSummaryRow(label: "Owner's Draws", amount: -ytdDraws, color: .purple)
                    .opacity(0.8)
            }

            Divider()

            // Net
            TaxSummaryRow(
                label: summary.netIncome >= 0 ? "Net Profit" : "Net Loss",
                amount: summary.netIncome,
                color: summary.netIncome >= 0 ? .green : .orange,
                isTotal: true
            )

            // SE Tax note
            if business.businessType.hasSelfEmploymentTax && summary.netIncome > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "dollarsign.circle")
                        .foregroundStyle(.orange)
                    Text("Subject to self-employment tax")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Pre-revenue farm note
            if business.businessType == .farm && summary.grossIncome == 0 && summary.totalExpenses > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(.green)
                    Text("Pre-revenue — expenses may be deductible as farm loss")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Transaction count
            Text("\(summary.transactionCount) transactions")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Summary Row Helper

struct TaxSummaryRow: View {
    let label: String
    let amount: Double
    let color: Color
    var isTotal: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(isTotal ? .subheadline.weight(.semibold) : .subheadline)
            Spacer()
            Text(amount.asCurrency)
                .font(isTotal ? .subheadline.weight(.bold) : .subheadline.monospacedDigit())
                .foregroundStyle(color)
        }
    }
}

// MARK: - Form Line Breakdown Card

struct FormLineBreakdownCard: View {
    let business: BusinessProfile
    let transactions: [Transaction]
    let year: Int

    @State private var isExpanded = false

    private var formLineTotals: [FormLineTotal] {
        TaxLineAggregationService.shared.aggregateByFormLine(
            business: business,
            transactions: transactions,
            year: year
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(.blue)
                    Text("\(business.businessType.taxFormName) Line Breakdown")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                let incomeLines = formLineTotals.filter { $0.isIncome }
                let expenseLines = formLineTotals.filter { !$0.isIncome }

                if !incomeLines.isEmpty {
                    Text("Income")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(incomeLines) { lineTotal in
                        formLineRow(lineTotal, color: .green)
                    }
                }

                if !expenseLines.isEmpty {
                    Text("Deductions")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    ForEach(expenseLines) { lineTotal in
                        formLineRow(lineTotal, color: .red)
                    }
                }

                if formLineTotals.isEmpty {
                    Text("No categorized transactions for \(String(year))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func formLineRow(_ lineTotal: FormLineTotal, color: Color) -> some View {
        HStack {
            Text(lineTotal.taxFormLine.badgeLabel)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)
            Text(lineTotal.taxFormLine.irsDescription)
                .font(.caption)
                .lineLimit(1)
            Spacer()
            Text(lineTotal.grossAmount.asCurrency)
                .font(.caption.monospacedDigit())
                .foregroundStyle(color)
        }
    }
}

// MARK: - Partner Allocations Card

struct PartnerAllocationsCard: View {
    let business: BusinessProfile
    let transactions: [Transaction]
    let year: Int

    @State private var isExpanded = false

    private var summaries: [PartnerK1Summary] {
        let formLineTotals = TaxLineAggregationService.shared.aggregateByFormLine(
            business: business, transactions: transactions, year: year
        )
        return TaxLineAggregationService.shared.partnerAllocations(
            business: business, formLineTotals: formLineTotals, year: year
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(.purple)
                    Text("K-1 Partner Allocations")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(summaries) { summary in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(summary.partner.partnerName)
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text(summary.partner.ownershipDisplay)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        TaxSummaryRow(
                            label: "Allocated Income",
                            amount: summary.ordinaryIncome,
                            color: summary.ordinaryIncome >= 0 ? .green : .orange
                        )

                        TaxSummaryRow(
                            label: "Capital Account",
                            amount: summary.endingCapital,
                            color: summary.endingCapital >= 0 ? .blue : .red
                        )

                        TaxSummaryRow(
                            label: "Outside Basis",
                            amount: summary.outsideBasis,
                            color: summary.outsideBasis > 0 ? .green : .red
                        )

                        if !summary.lossDeductible && summary.ordinaryIncome < 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.caption)
                                Text("Loss suspended under \(CarryforwardType.suspendedLoss704d.ircReference) — insufficient basis")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    if summary.id != summaries.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Depreciation Summary Card

struct DepreciationSummaryCard: View {
    let business: BusinessProfile
    let year: Int

    @State private var isExpanded = false

    private var activeAssets: [DepreciableAsset] {
        business.activeAssets
    }

    private var totalDepreciation: Double {
        MACRSCalculationService.shared.totalDepreciationForYear(year, assets: activeAssets)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundStyle(.teal)
                    Text("Depreciation Schedule")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(totalDepreciation.asCurrency)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.teal)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(activeAssets) { asset in
                    let yearDepr = asset.depreciationForYear(year)
                    let nbv = asset.netBookValue(atEndOfYear: year)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(asset.name)
                                .font(.caption.weight(.medium))
                            HStack(spacing: 6) {
                                Text(asset.propertyClass.displayName)
                                Text(asset.depreciationMethod.shortName)
                            }
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(yearDepr.asCurrency)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.teal)
                            Text("NBV: \(nbv.asCurrency)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Carryforward Summary Card

struct CarryforwardSummaryCard: View {
    let business: BusinessProfile

    @State private var isExpanded = false

    private var activeItems: [TaxCarryforward] {
        business.activeCarryforwards
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.uturn.forward.circle.fill")
                        .foregroundStyle(.orange)
                    Text("Carryforward Items")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(activeItems.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(activeItems) { item in
                    HStack {
                        Image(systemName: item.type.icon)
                            .foregroundStyle(item.type.color)
                            .font(.caption)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.type.displayName)
                                .font(.caption.weight(.medium))
                            if let partner = item.partnerName {
                                Text(partner)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Text("From \(String(item.originYear))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(item.remainingAmount.asCurrency)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(item.status.color)
                            Text(item.status.displayName)
                                .font(.caption2)
                                .foregroundStyle(item.status.color)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BusinessTaxSummaryView()
            .modelContainer(ModelContainer.preview())
    }
}
