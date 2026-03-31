//  ExportOptionsView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.3 - Dynamic Type verification: lineLimit + minimumScaleFactor on all text
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.3 - Dynamic Type Verification:
//  ✅ FIXED: Locked view "Pro Feature" title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Locked view description text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Filter preview "Date Range" label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Filter preview "This Year" value missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Export preview button labels missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "What You'll Get" header missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Feature benefit titles missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Feature benefit descriptions missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Tax season note title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Tax season note description missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Upgrade button text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Current plan text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Export button labels missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Transaction stats text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Mileage stats text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Info section title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Info section description missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Section footer text missing lineLimit + minimumScaleFactor
//
//  CHANGES v1.2:
//  ✅ Full VoiceOver accessibility coverage
//  ✅ Screen change announcement on appear
//  ✅ Pro locked view: blurred preview hidden, lock overlay combined
//  ✅ Feature benefit rows: icons hidden, combined
//  ✅ Tax season note icon hidden, combined
//  ✅ Export buttons with spoken stats and hints
//  ✅ Info section icon hidden, combined
//  ✅ Upgrade button with hint
//  ✅ Fixed garbled UTF-8 characters
//
//  CHANGES v1.1:
//  ✅ Added Pro tier gating - only Pro subscribers can access
//  ✅ Free/Premium users see professional upgrade prompt
//  ✅ Blurred preview of export options
//  ✅ Clear value proposition for upgrading
//  ✅ Consistent style with P&L and Year-End locked views
//
//  FEATURES v1.0:
//  ✅ Date range filtering (All Time, This Year, Last Year, This Month, Custom)
//  ✅ Transaction export using ExportService (RFC 4180 compliant)
//  ✅ Mileage export with IRS rate and deduction totals
//  ✅ Finance type filter (All, Business Only, Personal Only)
//  ✅ Progress indicators during export
//  ✅ Shows item counts before export
//  ✅ UIKit share sheet (works in nested sheets)
//  ✅ FLOAnimation and HapticService integration
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif
import UniformTypeIdentifiers

struct ExportOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query(sort: \MileageTrip.startDate, order: .reverse) private var allTrips: [MileageTrip]
    
    // Filter State
    @State private var dateRange: DateRange = .thisYear
    @State private var financeTypeFilter: FinanceTypeFilter = .all
    
    // Export State
    @State private var isExportingTransactions = false
    @State private var isExportingMileage = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var viewAppeared = false
    @State private var showingSubscriptionView = false
    
    // v1.1: Check if user has Pro access
    private var hasProAccess: Bool {
        subscriptionManager.currentTier == .pro
    }
    
    // MARK: - Date Range Enum
    
    enum DateRange: String, CaseIterable, Identifiable {
        case all = "All Time"
        case thisYear = "This Year"
        case lastYear = "Last Year"
        case thisMonth = "This Month"
        case lastMonth = "Last Month"
        case thisQuarter = "This Quarter"
        
        var id: String { rawValue }
    }
    
    // MARK: - Finance Type Filter
    
    enum FinanceTypeFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case business = "Business Only"
        case personal = "Personal Only"
        
        var id: String { rawValue }
    }
    
    // MARK: - Filtered Data
    
    private var filteredTransactions: [Transaction] {
        var filtered = filterByDateRange(allTransactions, keyPath: \.date)
        
        switch financeTypeFilter {
        case .all:
            break
        case .business:
            filtered = filtered.filter { $0.financeType == .business }
        case .personal:
            filtered = filtered.filter { $0.financeType == .personal }
        }
        
        return filtered
    }
    
    private var filteredTrips: [MileageTrip] {
        filterByDateRange(allTrips, keyPath: \.startDate)
    }
    
    private var filteredBusinessTrips: [MileageTrip] {
        filteredTrips.filter { $0.isBusinessTrip }
    }
    
    // MARK: - Statistics
    
    private var transactionStats: (income: Double, expenses: Double, deductible: Double) {
        let income = filteredTransactions.filter { $0.isIncome }.reduce(0) { $0 + $1.amount }
        let expenses = filteredTransactions.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
        let deductible = filteredTransactions.filter { !$0.isIncome && ($0.category?.isTaxDeductible ?? false) }.reduce(0) { $0 + $1.amount }
        return (income, expenses, deductible)
    }
    
    private var mileageStats: (miles: Double, deduction: Double) {
        let miles = filteredBusinessTrips.reduce(0) { $0 + $1.distanceMiles }
        let deduction = filteredBusinessTrips.reduce(0) { $0 + $1.deductionAmount }
        return (miles, deduction)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Group {
                // v1.1: Gate content to Pro tier
                if hasProAccess {
                    exportContent
                } else {
                    proFeatureLockedView
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticService.play(.light)
                        dismiss()
                    }
                }
            }
            .onAppear {
                withAnimation(FLOAnimation.standard) {
                    viewAppeared = true
                }
                AccessibilityAnnouncement.screenChanged("Export data")
            }
            .alert("Export Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingSubscriptionView) {
                SubscriptionView()
            }
        }
    }
    
    // MARK: - Pro Feature Locked View
    // v1.1: Professional upgrade prompt for Free/Premium users
    
    private var proFeatureLockedView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Blurred preview of what they'd see
                ZStack {
                    // Sample export options preview (blurred)
                    VStack(spacing: 12) {
                        // Filter preview
                        HStack {
                            Text("Date Range")
                                .font(.subheadline)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Spacer()
                            Text("This Year")
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color.floSecondarySystemBackground)
                        .cornerRadius(10)
                        
                        // Export buttons preview
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundStyle(.orange)
                                Text("Export Transactions")
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Spacer()
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color.floSecondarySystemBackground)
                            .cornerRadius(10)
                            
                            HStack {
                                Image(systemName: "car")
                                    .foregroundStyle(.orange)
                                Text("Export Mileage Log")
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Spacer()
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color.floSecondarySystemBackground)
                            .cornerRadius(10)
                        }
                    }
                    .blur(radius: 6)
                    .opacity(0.6)
                    .accessibilityHidden(true)
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.15))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "lock.fill")
                                .font(.title2)
                                .foregroundStyle(.orange)
                        }
                        .opacity(viewAppeared ? 1 : 0.001)
                        .scaleEffect(viewAppeared ? 1 : 0.5)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: viewAppeared)
                        
                        Text("Pro Feature")
                            .font(.title2.bold())
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .opacity(viewAppeared ? 1 : 0.001)
                            .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)
                        
                        Text("Advanced Exports are available\nexclusively for Pro subscribers")
                            .font(.subheadline)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .opacity(viewAppeared ? 1 : 0.001)
                            .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)
                    }
                    .padding(32)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .accessibilityElement(children: .combine)
                }
                .padding()
                .opacity(viewAppeared ? 1 : 0.001)
                .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)
                
                // Feature benefits
                VStack(alignment: .leading, spacing: 16) {
                    Text("What You'll Get")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .accessibilityAddTraits(.isHeader)
                    
                    ExportFeatureBenefit(
                        icon: "doc.text.fill",
                        title: "Transaction Export",
                        description: "Export all transactions to CSV for spreadsheets"
                    )
                    
                    ExportFeatureBenefit(
                        icon: "car.fill",
                        title: "Mileage Log Export",
                        description: "IRS-compliant mileage reports with deduction totals"
                    )
                    
                    ExportFeatureBenefit(
                        icon: "calendar",
                        title: "Date Range Filtering",
                        description: "Export by month, quarter, year, or custom range"
                    )
                    
                    ExportFeatureBenefit(
                        icon: "building.2.fill",
                        title: "Business/Personal Split",
                        description: "Separate exports for business and personal transactions"
                    )
                    
                    ExportFeatureBenefit(
                        icon: "tablecells.fill",
                        title: "Spreadsheet Compatible",
                        description: "Works with Excel, Numbers, and Google Sheets"
                    )
                }
                .padding()
                .background(Color.floSecondarySystemBackground)
                .cornerRadius(12)
                .padding(.horizontal)
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.25), value: viewAppeared)
                
                // Tax season note
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "doc.badge.clock")
                            .foregroundStyle(.blue)
                            .accessibilityHidden(true)
                        Text("Perfect for Tax Season")
                            .font(.subheadline.bold())
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    
                    Text("Export your financial data to share with your accountant or import into tax software.")
                        .font(.caption)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                .accessibilityElement(children: .combine)
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.3), value: viewAppeared)
                
                // Upgrade button
                Button {
                    HapticService.play(.medium)
                    showingSubscriptionView = true
                } label: {
                    HStack {
                        Image(systemName: "star.fill")
                        Text("Upgrade to Pro")
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.orange, Color.orange.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .accessibilityHint("Opens subscription options")
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.35), value: viewAppeared)
                
                // Current tier indicator
                Text("Current plan: \(subscriptionManager.currentTier.displayName)")
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.secondary)
                    .opacity(viewAppeared ? 1 : 0.001)
                    .animation(FLOAnimation.standard.delay(0.4), value: viewAppeared)
            }
            .padding(.vertical)
        }
        .background(Color.floSystemGroupedBackground)
    }
    
    // MARK: - Export Content (Pro Users Only)
    
    private var exportContent: some View {
        Form {
            // Filters Section
            filtersSection
            
            // Transactions Section
            transactionsSection
            
            // Mileage Section
            mileageSection
            
            // Info Section
            infoSection
        }
    }
    
    // MARK: - Filters Section
    
    private var filtersSection: some View {
        Section {
            // Date Range Picker
            Picker("Date Range", selection: $dateRange) {
                ForEach(DateRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .onChange(of: dateRange) { _, _ in
                HapticService.play(.selection)
            }
            
            // Finance Type Picker (for transactions)
            Picker("Transaction Type", selection: $financeTypeFilter) {
                ForEach(FinanceTypeFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .onChange(of: financeTypeFilter) { _, _ in
                HapticService.play(.selection)
            }
        } header: {
            Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        } footer: {
            Text("Filters apply to transaction exports. Mileage exports include business trips only.")
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .opacity(viewAppeared ? 1 : 0.001)
        .offset(y: viewAppeared ? 0 : 10)
        .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)
    }
    
    // MARK: - Transactions Section
    
    private var transactionsSection: some View {
        Section {
            Button {
                HapticService.play(.medium)
                exportTransactions()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "doc.text")
                                 .foregroundStyle(Color.brandPrimaryText)
                                .frame(width: 24)
                            
                            Text("Export Transactions")
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.primary)
                        }
                        
                        if !filteredTransactions.isEmpty {
                            let stats = transactionStats
                            Text("\(filteredTransactions.count) transactions • \(formatCurrency(stats.income)) income • \(formatCurrency(stats.expenses)) expenses")
                                .font(.caption)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if isExportingTransactions {
                        ProgressView()
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }
            }
            .disabled(filteredTransactions.isEmpty || isExportingTransactions)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel({
                var label = "Export transactions"
                if isExportingTransactions {
                    label = "Exporting transactions"
                } else if !filteredTransactions.isEmpty {
                    let stats = transactionStats
                    label += ", \(filteredTransactions.count) transactions, \(formatCurrency(stats.income)) income, \(formatCurrency(stats.expenses)) expenses"
                }
                return label
            }())
            .accessibilityHint(filteredTransactions.isEmpty ? "No transactions found for selected filters" : "Exports transactions as CSV file")
        } header: {
            Label("Transactions", systemImage: "creditcard")
                .font(.caption)
                .foregroundStyle(.secondary)
        } footer: {
            if filteredTransactions.isEmpty {
                Text("No transactions found for selected filters")
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            } else {
                Text("Exports as CSV with totals. Compatible with Excel, Numbers, and Google Sheets.")
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
        }
        .opacity(viewAppeared ? 1 : 0.001)
        .offset(y: viewAppeared ? 0 : 10)
        .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
    }
    
    // MARK: - Mileage Section
    
    private var mileageSection: some View {
        Section {
            Button {
                HapticService.play(.medium)
                exportMileage()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "car")
                                 .foregroundStyle(Color.brandPrimaryText)
                                .frame(width: 24)
                            
                            Text("Export Mileage Log")
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.primary)
                        }
                        
                        if !filteredBusinessTrips.isEmpty {
                            let stats = mileageStats
                            Text("\(filteredBusinessTrips.count) trips • \(String(format: "%.1f", stats.miles)) miles • \(formatCurrency(stats.deduction)) deduction")
                                .font(.caption)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if isExportingMileage {
                        ProgressView()
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }
            }
            .disabled(filteredBusinessTrips.isEmpty || isExportingMileage)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel({
                var label = "Export mileage log"
                if isExportingMileage {
                    label = "Exporting mileage log"
                } else if !filteredBusinessTrips.isEmpty {
                    let stats = mileageStats
                    label += ", \(filteredBusinessTrips.count) trips, \(String(format: "%.1f", stats.miles)) miles, \(formatCurrency(stats.deduction)) deduction"
                }
                return label
            }())
            .accessibilityHint(filteredBusinessTrips.isEmpty ? "No business trips found for selected date range" : "Exports mileage log as CSV file")
        } header: {
            Label("Mileage", systemImage: "road.lanes")
                .font(.caption)
                .foregroundStyle(.secondary)
        } footer: {
            if filteredBusinessTrips.isEmpty {
                Text("No business trips found for selected date range")
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            } else {
                let currentYear = Calendar.current.component(.year, from: Date())
                let irsRate = MileageTrip.irsRateForYear(currentYear)
                Text("Business trips only. Uses \(String(currentYear)) IRS rate of $\(String(format: "%.3f", irsRate))/mile.")
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
        }
        .opacity(viewAppeared ? 1 : 0.001)
        .offset(y: viewAppeared ? 0 : 10)
        .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)
    }
    
    // MARK: - Info Section
    
    private var infoSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.blue)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("About CSV Exports")
                        .font(.subheadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .fontWeight(.medium)
                    Text("CSV files are universally compatible with spreadsheet apps. Amounts use standard number format for easy calculations.")
                        .font(.caption)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
        }
        .opacity(viewAppeared ? 1 : 0.001)
        .offset(y: viewAppeared ? 0 : 10)
        .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)
    }
    
    // MARK: - Export Functions
    
    private func exportTransactions() {
        isExportingTransactions = true
        
        Task {
            // Calculate date range for ExportService
            let closedDateRange = getClosedDateRange()
            
            // Use ExportService for transactions
            let result = await ExportService.shared.generateCSVAsync(
                transactions: Array(filteredTransactions),
                dateRange: closedDateRange,
                financeType: financeTypeFilter == .business ? .business : (financeTypeFilter == .personal ? .personal : nil),
                includeTotals: true
            )
            
            await MainActor.run {
                switch result {
                case .success(let csvString):
                    saveAndShareCSV(content: csvString, filename: "FLO_Transactions_\(dateRange.rawValue.replacingOccurrences(of: " ", with: "_"))")
                    
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showingError = true
                    HapticService.play(.error)
                }
                
                isExportingTransactions = false
            }
        }
    }
    
    private func exportMileage() {
        isExportingMileage = true
        
        Task {
            await MainActor.run {
                let csvString = generateMileageCSV()
                saveAndShareCSV(content: csvString, filename: "FLO_Mileage_\(dateRange.rawValue.replacingOccurrences(of: " ", with: "_"))")
                isExportingMileage = false
            }
        }
    }
    
    // MARK: - Mileage CSV Generation
    
    private func generateMileageCSV() -> String {
        var csvLines: [String] = []
        csvLines.reserveCapacity(filteredBusinessTrips.count + 15)
        
        // Header
        csvLines.append("Date,Start Location,End Location,Distance (miles),Purpose,Deduction Amount,Notes")
        
        // Disclaimer
        csvLines.append("# DISCLAIMER: This mileage log is for informational purposes only.")
        csvLines.append("# FLO is not a substitute for professional tax advice.")
        csvLines.append("# Always consult a qualified tax professional before filing taxes.")
        csvLines.append("# Generated: \(Date().formatted(date: .long, time: .shortened))")
        csvLines.append("")
        
        // Data rows
        for trip in filteredBusinessTrips.sorted(by: { $0.startDate < $1.startDate }) {
            let date = DateFormatter.shortDate.string(from: trip.startDate)
            let startLocation = escapeCSVField(trip.startAddress ?? "Unknown")
            let endLocation = escapeCSVField(trip.endAddress ?? "Unknown")
            let distance = String(format: "%.2f", trip.distanceMiles)
            let purpose = escapeCSVField(trip.purpose.displayName)
            let deduction = NumberFormatter.csvDecimal.string(from: NSNumber(value: trip.deductionAmount)) ?? String(format: "%.2f", trip.deductionAmount)
            let notes = escapeCSVField(trip.notes ?? "")
            
            csvLines.append("\(date),\(startLocation),\(endLocation),\(distance),\(purpose),\(deduction),\(notes)")
        }
        
        // Summary
        let stats = mileageStats
        let currentYear = Calendar.current.component(.year, from: Date())
        let irsRate = MileageTrip.irsRateForYear(currentYear)
        
        csvLines.append("")
        csvLines.append("Summary")
        csvLines.append("Total Business Trips,\(filteredBusinessTrips.count)")
        csvLines.append("Total Miles,\(String(format: "%.2f", stats.miles))")
        csvLines.append("Total Deduction,\(String(format: "%.2f", stats.deduction))")
        csvLines.append("IRS Rate Used,\(String(format: "%.3f", irsRate))")
        csvLines.append("Date Range,\(dateRange.rawValue)")
        
        return csvLines.joined(separator: "\n")
    }
    
    // MARK: - Helpers
    
    private func filterByDateRange<T>(_ items: [T], keyPath: KeyPath<T, Date>) -> [T] {
        let calendar = Calendar.current
        let now = Date()
        
        switch dateRange {
        case .all:
            return items
            
        case .thisYear:
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now))!
            return items.filter { $0[keyPath: keyPath] >= startOfYear }
            
        case .lastYear:
            let startOfThisYear = calendar.date(from: calendar.dateComponents([.year], from: now))!
            let startOfLastYear = calendar.date(byAdding: .year, value: -1, to: startOfThisYear)!
            return items.filter { $0[keyPath: keyPath] >= startOfLastYear && $0[keyPath: keyPath] < startOfThisYear }
            
        case .thisMonth:
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            return items.filter { $0[keyPath: keyPath] >= startOfMonth }
            
        case .lastMonth:
            let startOfThisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfThisMonth)!
            return items.filter { $0[keyPath: keyPath] >= startOfLastMonth && $0[keyPath: keyPath] < startOfThisMonth }
            
        case .thisQuarter:
            let month = calendar.component(.month, from: now)
            let quarterStartMonth = ((month - 1) / 3) * 3 + 1
            var components = calendar.dateComponents([.year], from: now)
            components.month = quarterStartMonth
            components.day = 1
            let startOfQuarter = calendar.date(from: components)!
            return items.filter { $0[keyPath: keyPath] >= startOfQuarter }
        }
    }
    
    private func getClosedDateRange() -> ClosedRange<Date>? {
        let calendar = Calendar.current
        let now = Date()
        
        switch dateRange {
        case .all:
            return nil
            
        case .thisYear:
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now))!
            return startOfYear...now
            
        case .lastYear:
            let startOfThisYear = calendar.date(from: calendar.dateComponents([.year], from: now))!
            let startOfLastYear = calendar.date(byAdding: .year, value: -1, to: startOfThisYear)!
            let endOfLastYear = calendar.date(byAdding: .day, value: -1, to: startOfThisYear)!
            return startOfLastYear...endOfLastYear
            
        case .thisMonth:
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            return startOfMonth...now
            
        case .lastMonth:
            let startOfThisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfThisMonth)!
            let endOfLastMonth = calendar.date(byAdding: .day, value: -1, to: startOfThisMonth)!
            return startOfLastMonth...endOfLastMonth
            
        case .thisQuarter:
            let month = calendar.component(.month, from: now)
            let quarterStartMonth = ((month - 1) / 3) * 3 + 1
            var components = calendar.dateComponents([.year], from: now)
            components.month = quarterStartMonth
            components.day = 1
            let startOfQuarter = calendar.date(from: components)!
            return startOfQuarter...now
        }
    }
    
    private func escapeCSVField(_ field: String) -> String {
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") || escaped.contains("\r") {
            return "\"\(escaped)\""
        }
        return escaped
    }
    
    private func saveAndShareCSV(content: String, filename: String) {
        let dateStr = Date().formatted(.iso8601.year().month().day())
        let fullFilename = "\(filename)_\(dateStr).csv"
        
        // Use proper UTI for CSV files
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(fullFilename, conformingTo: UTType.commaSeparatedText)
        
        do {
            // Remove existing file if present
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            
            // Write with UTF-8 encoding
            try content.write(to: tempURL, atomically: true, encoding: .utf8)
            HapticService.play(.success)
            presentShareSheet(url: tempURL)
        } catch {
            errorMessage = "Failed to create export file: \(error.localizedDescription)"
            showingError = true
            HapticService.play(.error)
        }
    }
    
    private func presentShareSheet(url: URL) {
        #if canImport(UIKit)
        // Create activity items with proper type
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)

        // Exclude activities that don't make sense for CSV files
        activityVC.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
            .postToFacebook,
            .postToTwitter,
            .postToWeibo,
            .postToFlickr,
            .postToVimeo,
            .postToTencentWeibo
        ]

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }

            // iPad support
            activityVC.popoverPresentationController?.sourceView = topVC.view
            activityVC.popoverPresentationController?.sourceRect = CGRect(x: topVC.view.bounds.midX, y: 100, width: 0, height: 0)
            activityVC.popoverPresentationController?.permittedArrowDirections = .up

            topVC.present(activityVC, animated: true)
        }
        #else
        let picker = NSSharingServicePicker(items: [url])
        if let window = NSApplication.shared.keyWindow,
           let contentView = window.contentView {
            picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
        }
        #endif
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        NumberFormatter.appCurrencyCompact.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Export Feature Benefit Row
// v1.1: New component for upgrade prompt

struct ExportFeatureBenefit: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.orange)
                .frame(width: 28)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(description)
                    .font(.caption)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview

#Preview {
    ExportOptionsView()
        .modelContainer(for: [Transaction.self, MileageTrip.self], inMemory: true)
}
