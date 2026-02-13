//  ReportsSupportingViews.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Extracted from ReportsView v3.5 (Sprint 5a)
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CONTENTS:
//  ✅ TaxDeadlineCountdownCard - Quarterly tax deadline with urgency levels
//  ✅ EnhancedStatCard - Income/expense/net stat cards with trends
//  ✅ MonthComparisonCard - Monthly income/expense/net comparison
//  ✅ InsightRow - Individual insight row with icon and text
//  ✅ TaxDeductibleSummary - Deductible expense totals
//  ✅ ReportExportSheet - Export modal with format, options, preview
//
//  ACCESSIBILITY (Sprint 5a):
//  ✅ All cards combined with spoken currency via AccessibilityFormatters
//  ✅ TaxDeadlineCountdownCard includes urgency context
//  ✅ EnhancedStatCard includes trend direction
//  ✅ ReportExportSheet preview rows with spoken currency
//  ✅ Decorative icons hidden throughout
//  ✅ Export button state-aware labels with hints
//

import SwiftUI

// MARK: - Tax Deadline Countdown Card

struct TaxDeadlineCountdownCard: View {
    @State private var iconAppeared = false
    
    private var nextDeadline: Date? { TaxSettings.nextQuarterlyDeadline() }
    private var daysUntilDeadline: Int? {
        guard let deadline = nextDeadline else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: deadline).day
    }
    
    private var urgencyLevel: UrgencyLevel {
        guard let days = daysUntilDeadline else { return .none }
        if days <= 7 { return .urgent }
        if days <= 14 { return .warning }
        if days <= 30 { return .upcoming }
        return .relaxed
    }
    
    enum UrgencyLevel {
        case urgent, warning, upcoming, relaxed, none
        
        var color: Color {
            switch self {
            case .urgent: return .red
            case .warning: return .orange
            case .upcoming: return Color.brandPrimary
            case .relaxed: return .incomeGreen
            case .none: return .secondary
            }
        }
        
        var icon: String {
            switch self {
            case .urgent: return "exclamationmark.triangle.fill"
            case .warning: return "clock.badge.exclamationmark.fill"
            case .upcoming: return "calendar.badge.clock"
            case .relaxed: return "checkmark.circle.fill"
            case .none: return "calendar"
            }
        }
    }
    
    var body: some View {
        if let days = daysUntilDeadline, let deadline = nextDeadline {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: urgencyLevel.icon)
                        .font(.title2)
                        .foregroundStyle(urgencyLevel.color)
                        .symbolEffect(.bounce, value: iconAppeared)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next Tax Deadline")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(deadline, style: .date)
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(days)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(urgencyLevel.color)
                            .contentTransition(.numericText())
                        Text("days left")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if urgencyLevel == .urgent || urgencyLevel == .warning {
                    Text(urgencyLevel == .urgent ?
                         "Payment due soon! Make sure to submit your estimated taxes." :
                         "Deadline approaching. Prepare your estimated tax payment.")
                        .font(.caption)
                        .foregroundStyle(urgencyLevel.color)
                }
            }
            .padding()
            .background(urgencyLevel.color.opacity(0.1))
            .cornerRadius(16)
            .padding(.horizontal)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel({
                var label = "Next tax deadline: \(days) days left"
                if urgencyLevel == .urgent {
                    label += ". Urgent: Payment due soon, make sure to submit your estimated taxes"
                } else if urgencyLevel == .warning {
                    label += ". Warning: Deadline approaching, prepare your estimated tax payment"
                }
                return label
            }())
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    iconAppeared = true
                }
            }
        }
    }
}

// MARK: - Enhanced Stat Card with Trends

struct EnhancedStatCard: View {
    let title: String
    let amount: Double
    let color: Color
    let icon: String
    let trend: Double?
    
    private var currencyCode: String { Locale.current.currency?.identifier ?? "USD" }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text(amount, format: .currency(code: currencyCode))
                .font(.system(.callout, design: .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .contentTransition(.numericText())
            
            if let trend = trend {
                HStack(spacing: 2) {
                    Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2)
                    Text("\(String(format: "%.1f", abs(trend)))%")
                        .font(.caption2)
                }
                .foregroundStyle(
                    trend >= 0 ?
                    (title == "Expenses" ? Color.expenseRed : Color.incomeGreen) :
                    (title == "Expenses" ? Color.incomeGreen : Color.expenseRed)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel({
            var label = "\(title): \(AccessibilityFormatters.spokenCurrency(amount))"
            if let trend = trend {
                let direction = trend >= 0 ? "up" : "down"
                label += ", trending \(direction) \(String(format: "%.1f", abs(trend))) percent"
            }
            return label
        }())
    }
}

// MARK: - Month Comparison Card

struct MonthComparisonCard: View {
    let data: MonthlyData
    let currencyCode: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(data.label)
                .font(.headline)
                 .foregroundStyle(Color.brandPrimaryText)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(Color.incomeGreen)
                        .font(.caption)
                    Text(data.income, format: .currency(code: currencyCode))
                        .font(.caption)
                        .foregroundStyle(Color.incomeGreen)
                        .contentTransition(.numericText())
                }
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(Color.expenseRed)
                        .font(.caption)
                    Text(data.expense, format: .currency(code: currencyCode))
                        .font(.caption)
                        .foregroundStyle(Color.expenseRed)
                        .contentTransition(.numericText())
                }
            }
            
            Divider()
            
            HStack {
                Text("Net:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(data.netCashFlow, format: .currency(code: currencyCode))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(data.netCashFlow >= 0 ? Color.incomeGreen : Color.expenseRed)
                    .contentTransition(.numericText())
            }
        }
        .padding()
        .frame(width: 140)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(data.label): income \(AccessibilityFormatters.spokenCurrency(data.income)), expenses \(AccessibilityFormatters.spokenCurrency(data.expense)), net \(data.netCashFlow >= 0 ? "positive" : "negative") \(AccessibilityFormatters.spokenCurrency(abs(data.netCashFlow)))")
    }
}

// MARK: - Insight Row

struct InsightRow: View {
    let icon: String
    let color: Color
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.subheadline)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Tax Deductible Summary

struct TaxDeductibleSummary: View {
    let transactions: [Transaction]
    
    private var currencyCode: String { Locale.current.currency?.identifier ?? "USD" }
    
    var deductibleAmount: Double {
        transactions
            .filter { !$0.isIncome && ($0.category?.isTaxDeductible ?? false) }
            .reduce(0) { $0 + $1.amount }
    }
    
    var deductibleCount: Int {
        transactions
            .filter { !$0.isIncome && ($0.category?.isTaxDeductible ?? false) }
            .count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundStyle(Color.incomeGreen)
                    .accessibilityHidden(true)
                Text("Tax Deductible Expenses")
                    .font(.headline)
            }
            .padding(.horizontal)
            .accessibilityAddTraits(.isHeader)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Deductible")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(deductibleAmount, format: .currency(code: currencyCode))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.incomeGreen)
                        .contentTransition(.numericText())
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Transactions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(deductibleCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .contentTransition(.numericText())
                }
            }
            .padding()
            .background(Color.incomeGreen.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Tax deductible expenses: \(AccessibilityFormatters.spokenCurrency(deductibleAmount)) across \(deductibleCount) transactions")
        }
        .padding(.vertical)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

// MARK: - Report Export Sheet

struct ReportExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    let transactions: [Transaction]
    let allTransactions: [Transaction]
    let dateRangeText: String
    let selectedPeriod: ReportsView.TimePeriod
    let totalIncome: Double
    let totalExpense: Double
    let businessExpenses: Double
    
    enum ExportFormat: String, CaseIterable {
        case pdf = "PDF"
        case csv = "CSV"
        
        var icon: String {
            switch self {
            case .pdf: return "doc.richtext.fill"
            case .csv: return "tablecells.fill"
            }
        }
    }
    
    @State private var exportFormat: ExportFormat = .pdf
    @State private var includeAllTransactions = false
    @State private var includeTotals = true
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var showShareSheet = false
    @State private var exportedData: Data?
    @State private var exportedURL: URL?
    
    private var transactionsToExport: [Transaction] {
        includeAllTransactions ? allTransactions : transactions
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Format", selection: $exportFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Label(format.rawValue, systemImage: format.icon).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: exportFormat) { _, _ in
                        HapticService.play(.selection)
                    }
                } header: {
                    Text("Export Format")
                }
                
                Section {
                    Toggle("Include All Transactions", isOn: $includeAllTransactions)
                        .onChange(of: includeAllTransactions) { _, _ in
                            HapticService.play(.light)
                        }
                    if exportFormat == .csv {
                        Toggle("Include Totals Row", isOn: $includeTotals)
                            .onChange(of: includeTotals) { _, _ in
                                HapticService.play(.light)
                            }
                    }
                } header: {
                    Text("Options")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Period:")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(includeAllTransactions ? "All Time" : dateRangeText)
                                .fontWeight(.medium)
                        }
                        .accessibilityElement(children: .combine)
                        HStack {
                            Text("Transactions:")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(transactionsToExport.count)")
                                .fontWeight(.medium)
                                .contentTransition(.numericText())
                        }
                        .accessibilityElement(children: .combine)
                        HStack {
                            Text("Income:")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(totalIncome, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                .foregroundStyle(Color.incomeGreen)
                                .fontWeight(.medium)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Income: \(AccessibilityFormatters.spokenCurrency(totalIncome))")
                        HStack {
                            Text("Expenses:")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(totalExpense, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                .foregroundStyle(Color.expenseRed)
                                .fontWeight(.medium)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Expenses: \(AccessibilityFormatters.spokenCurrency(totalExpense))")
                        if businessExpenses > 0 {
                            HStack {
                                Text("Business (Deductible):")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(businessExpenses, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                    .foregroundStyle(Color.businessColor)
                                    .fontWeight(.medium)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Business deductible: \(AccessibilityFormatters.spokenCurrency(businessExpenses))")
                        }
                    }
                } header: {
                    Text("Export Preview")
                }
                
                if let error = exportError {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .accessibilityHidden(true)
                            Text(error)
                                .foregroundStyle(.red)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Export error: \(error)")
                    }
                }
                
                Section {
                    Button {
                        HapticService.play(.medium)
                        performExport()
                    } label: {
                        HStack {
                            Spacer()
                            if isExporting {
                                ProgressView()
                                    .padding(.trailing, 8)
                                    .accessibilityHidden(true)
                            }
                            Image(systemName: "square.and.arrow.up")
                                .accessibilityHidden(true)
                            Text("Export & Share")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(isExporting || transactionsToExport.isEmpty)
                    .accessibilityLabel(isExporting ? "Exporting report" : "Export and share report")
                    .accessibilityHint("Exports \(transactionsToExport.count) transactions as \(exportFormat.rawValue)")
                }
            }
            .navigationTitle("Export Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticService.play(.light)
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let data = exportedData {
                    ShareSheet(items: [data])
                } else if let url = exportedURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }
    
    private func performExport() {
        isExporting = true
        exportError = nil
        
        Task {
            switch exportFormat {
            case .pdf:
                let result = ExportService.shared.generatePDF(
                    transactions: transactionsToExport,
                    title: "FLO Financial Report - \(includeAllTransactions ? "All Time" : dateRangeText)"
                )
                switch result {
                case .success(let data):
                    exportedData = data
                    isExporting = false
                    showShareSheet = true
                case .failure(let error):
                    exportError = error.localizedDescription
                    isExporting = false
                }
                
            case .csv:
                let result = ExportService.shared.generateCSV(
                    transactions: transactionsToExport,
                    includeTotals: includeTotals
                )
                switch result {
                case .success(let csv):
                    let filename = "FLO_Report_\(Date().formatted(.iso8601.year().month().day()))"
                    let saveResult = ExportService.shared.saveCSVToTemporaryFile(csv: csv, filename: filename)
                    switch saveResult {
                    case .success(let url):
                        exportedURL = url
                        isExporting = false
                        showShareSheet = true
                    case .failure(let error):
                        exportError = error.localizedDescription
                        isExporting = false
                    }
                case .failure(let error):
                    exportError = error.localizedDescription
                    isExporting = false
                }
            }
        }
    }
}
