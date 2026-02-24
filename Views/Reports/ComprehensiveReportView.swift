//  ComprehensiveReportView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.4 - Dark Mode Optimization: Adaptive color fixes
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.4 - Dark Mode Optimization:
//  ✅ FIXED: L580 Color.gray → Color(.systemGray4) for generate button background (adapts to dark mode)
//
//  CHANGES v1.3 - Dynamic Type Verification:
//  ✅ FIXED: Header "CPA-Ready Reports" title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Header description text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Report Type" section header missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Report type button labels missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Date Range" section header missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Date range summary text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Include Sections" header missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Toggle row title labels missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Toggle row subtitle labels missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Data Preview" section header missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Preview card count text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Preview card label text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Empty state warning text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Generate button text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Tips for Your CPA" header missing lineLimit + minimumScaleFactor
//  ✅ FIXED: CPA tip text rows missing lineLimit + minimumScaleFactor
//
//  CHANGES v1.2:
//  ✅ Full VoiceOver accessibility coverage
//  ✅ Screen change announcement on appear
//  ✅ All section headers marked with .isHeader trait
//  ✅ Report type buttons accessible with selected state
//  ✅ Toggle rows combined with icon hidden and hint
//  ✅ Preview cards combined with spoken counts
//  ✅ Generate button labeled with state and hint
//  ✅ CPA tips section combined, checkmark icons hidden
//  ✅ Warning empty state accessible with icon hidden
//  ✅ Header decorative icon hidden
//  ✅ Date range summary accessible
//
//  FEATURES:
//  ✅ Annual and quarterly report options
//  ✅ Custom date range selection
//  ✅ Toggle sections (mileage, invoices, transactions)
//  ✅ Business profile integration
//  ✅ Preview report sections
//  ✅ Share/export functionality
//

import SwiftUI
import SwiftData

struct ComprehensiveReportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var transactions: [Transaction]
    @Query private var mileageTrips: [MileageTrip]
    @Query private var invoices: [Invoice]
    @Query private var taxSettingsQuery: [TaxSettings]
    @Query private var businessProfiles: [BusinessProfile]
    
    // Report Configuration State
    @State private var reportType: ReportType = .annual
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedQuarter: Int = 1
    @State private var customStartDate = Date()
    @State private var customEndDate = Date()
    
    // Section Toggles
    @State private var includeMileage = true
    @State private var includeInvoices = true
    @State private var includeDetailedTransactions = true
    @State private var includeTaxEstimates = true
    @State private var includePersonal = true
    
    // UI State
    @State private var isGenerating = false
    @State private var generatedPDF: Data?
    @State private var showingShareSheet = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var viewAppeared = false
    
    // Haptics
                
    private var taxSettings: TaxSettings? { taxSettingsQuery.first }
    private var businessProfile: BusinessProfile? { businessProfiles.first }
    
    enum ReportType: String, CaseIterable {
        case annual = "Annual Report"
        case quarterly = "Quarterly Report"
        case custom = "Custom Date Range"
        
        var icon: String {
            switch self {
            case .annual: return "calendar"
            case .quarterly: return "calendar.badge.clock"
            case .custom: return "calendar.badge.plus"
            }
        }
    }
    
    private var dateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        
        switch reportType {
        case .annual:
            let start = calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1))!
            let end = calendar.date(from: DateComponents(year: selectedYear, month: 12, day: 31))!
            return start...end
            
        case .quarterly:
            let startMonth = (selectedQuarter - 1) * 3 + 1
            let start = calendar.date(from: DateComponents(year: selectedYear, month: startMonth, day: 1))!
            let end = calendar.date(from: DateComponents(year: selectedYear, month: startMonth + 2 + 1, day: 0))!
            return start...end
            
        case .custom:
            return customStartDate...customEndDate
        }
    }
    
    private var reportTitle: String {
        switch reportType {
        case .annual:
            return "\(selectedYear) Annual Financial Report"
        case .quarterly:
            return "Q\(selectedQuarter) \(selectedYear) Financial Report"
        case .custom:
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return "Financial Report: \(formatter.string(from: customStartDate)) - \(formatter.string(from: customEndDate))"
        }
    }
    
    // Preview counts
    private var filteredTransactionCount: Int {
        transactions.filter { dateRange.contains($0.date) }.count
    }
    
    private var filteredMileageCount: Int {
        mileageTrips.filter { dateRange.contains($0.startDate) }.count
    }
    
    private var filteredInvoiceCount: Int {
        invoices.filter { dateRange.contains($0.issueDate) }.count
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                        .opacity(viewAppeared ? 1 : 0.001)
                        .offset(y: viewAppeared ? 0 : 20)
                        .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
                    
                    // Report Type Selection
                    reportTypeSection
                        .opacity(viewAppeared ? 1 : 0.001)
                        .offset(y: viewAppeared ? 0 : 20)
                        .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)
                    
                    // Date Selection
                    dateSelectionSection
                        .opacity(viewAppeared ? 1 : 0.001)
                        .offset(y: viewAppeared ? 0 : 20)
                        .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)
                    
                    // Report Sections
                    sectionsToggleSection
                        .opacity(viewAppeared ? 1 : 0.001)
                        .offset(y: viewAppeared ? 0 : 20)
                        .animation(FLOAnimation.standard.delay(0.25), value: viewAppeared)
                    
                    // Data Preview
                    dataPreviewSection
                        .opacity(viewAppeared ? 1 : 0.001)
                        .offset(y: viewAppeared ? 0 : 20)
                        .animation(FLOAnimation.standard.delay(0.3), value: viewAppeared)
                    
                    // Generate Button
                    generateButton
                        .opacity(viewAppeared ? 1 : 0.001)
                        .offset(y: viewAppeared ? 0 : 20)
                        .animation(FLOAnimation.standard.delay(0.35), value: viewAppeared)
                    
                    // CPA Tips
                    cpaTipsSection
                        .opacity(viewAppeared ? 1 : 0.001)
                        .offset(y: viewAppeared ? 0 : 20)
                        .animation(FLOAnimation.standard.delay(0.4), value: viewAppeared)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Generate Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticService.play(.light)
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let data = generatedPDF {
                    ShareSheet(items: [data])
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                // Set default quarter based on current date
                let month = Calendar.current.component(.month, from: Date())
                selectedQuarter = (month - 1) / 3 + 1
                
                // Set custom dates to current month
                let calendar = Calendar.current
                customStartDate = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
                customEndDate = Date()
                
                withAnimation {
                    viewAppeared = true
                }
                AccessibilityAnnouncement.screenChanged("Generate CPA-ready report")
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.businessColor.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "doc.text.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color.businessColor)
            }
            .accessibilityHidden(true)
            
            Text("CPA-Ready Reports")
                .font(.title2)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text("Generate comprehensive financial reports for tax preparation, budgeting, or sharing with your accountant.")
                .font(.subheadline)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical)
        .accessibilityElement(children: .combine)
    }
    
    // MARK: - Report Type Section
    
    private var reportTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Report Type")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            
            HStack(spacing: 12) {
                ForEach(ReportType.allCases, id: \.self) { type in
                    Button {
                        HapticService.play(.light)
                        withAnimation(FLOAnimation.quick) {
                            reportType = type
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: type.icon)
                                .font(.title2)
                                .accessibilityHidden(true)
                            Text(type.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(reportType == type ? Color.businessColor : Color(.secondarySystemBackground))
                        )
                        .foregroundStyle(reportType == type ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(type.rawValue)
                    .accessibilityAddTraits(reportType == type ? [.isSelected] : [])
                    .accessibilityHint(reportType == type ? "Currently selected" : "Double tap to select")
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Date Selection Section
    
    private var dateSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Date Range")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            
            switch reportType {
            case .annual:
                Picker("Year", selection: $selectedYear) {
                    ForEach((2020...Calendar.current.component(.year, from: Date())).reversed(), id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedYear) { _, _ in
                    HapticService.play(.light)
                }
                
            case .quarterly:
                HStack {
                    Picker("Quarter", selection: $selectedQuarter) {
                        Text("Q1 (Jan-Mar)").tag(1)
                        Text("Q2 (Apr-Jun)").tag(2)
                        Text("Q3 (Jul-Sep)").tag(3)
                        Text("Q4 (Oct-Dec)").tag(4)
                    }
                    .pickerStyle(.menu)
                    
                    Picker("Year", selection: $selectedYear) {
                        ForEach((2020...Calendar.current.component(.year, from: Date())).reversed(), id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .onChange(of: selectedQuarter) { _, _ in
                    HapticService.play(.light)
                }
                
            case .custom:
                VStack(spacing: 12) {
                    DatePicker("Start Date", selection: $customStartDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $customEndDate, in: customStartDate..., displayedComponents: .date)
                }
            }
            
            // Date range summary
                        Text("Period: \(dateRange.lowerBound.formatted(date: .abbreviated, time: .omitted)) - \(dateRange.upperBound.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Sections Toggle
    
    private var sectionsToggleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Include Sections")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            
            VStack(spacing: 0) {
                toggleRow(
                    icon: "car.fill",
                    title: "Mileage Log",
                    subtitle: "IRS-compliant mileage deductions",
                    isOn: $includeMileage
                )
                
                Divider().padding(.leading, 50)
                
                toggleRow(
                    icon: "doc.text.fill",
                    title: "Invoice Summary",
                    subtitle: "Outstanding and paid invoices",
                    isOn: $includeInvoices
                )
                
                Divider().padding(.leading, 50)
                
                toggleRow(
                    icon: "list.bullet.rectangle",
                    title: "Detailed Transactions",
                    subtitle: "Full transaction listing",
                    isOn: $includeDetailedTransactions
                )
                
                Divider().padding(.leading, 50)
                
                toggleRow(
                    icon: "percent",
                    title: "Tax Estimates",
                    subtitle: "Quarterly estimated taxes",
                    isOn: $includeTaxEstimates
                )
                
                Divider().padding(.leading, 50)
                
                toggleRow(
                    icon: "person.fill",
                    title: "Personal Expenses",
                    subtitle: "Include non-business transactions",
                    isOn: $includePersonal
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private func toggleRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.businessColor)
                .frame(width: 30)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(subtitle)
                    .font(.caption)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.businessColor)
                .onChange(of: isOn.wrappedValue) { _, _ in
                    HapticService.play(.light)
                }
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)")
        .accessibilityValue(isOn.wrappedValue ? "Included" : "Excluded")
        .accessibilityHint(subtitle)
    }
    
    // MARK: - Data Preview Section
    
    private var dataPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Preview")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            
            HStack(spacing: 16) {
                previewCard(
                    icon: "arrow.left.arrow.right",
                    count: filteredTransactionCount,
                    label: "Transactions"
                )
                
                if includeMileage {
                    previewCard(
                        icon: "car.fill",
                        count: filteredMileageCount,
                        label: "Trips"
                    )
                }
                
                if includeInvoices {
                    previewCard(
                        icon: "doc.text.fill",
                        count: filteredInvoiceCount,
                        label: "Invoices"
                    )
                }
            }
            
            if filteredTransactionCount == 0 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                    Text("No transactions found for this period")
                        .font(.caption)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Warning: No transactions found for this period")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private func previewCard(icon: String, count: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.businessColor)
                .accessibilityHidden(true)
            
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(label)
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) \(label)")
    }
    
    // MARK: - Generate Button
    
    private var generateButton: some View {
        Button {
            HapticService.play(.medium)
            generateReport()
        } label: {
            HStack(spacing: 12) {
                if isGenerating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: "doc.badge.plus")
                        .accessibilityHidden(true)
                }
                
                Text(isGenerating ? "Generating Report..." : "Generate CPA-Ready Report")
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(filteredTransactionCount > 0 ? Color.businessColor : Color(.systemGray4))
            )
            .foregroundStyle(.white)
        }
        .disabled(isGenerating || filteredTransactionCount == 0)
        .scaleEffect(isGenerating ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isGenerating)
        .accessibilityLabel(isGenerating ? "Generating report" : "Generate CPA-ready report")
        .accessibilityHint(filteredTransactionCount == 0 ? "No transactions available for this period" : "Generates a comprehensive PDF report with \(filteredTransactionCount) transactions")
    }
    
    // MARK: - CPA Tips Section
    
    private var cpaTipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                    .accessibilityHidden(true)
                Text("Tips for Your CPA")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .accessibilityAddTraits(.isHeader)
            
            VStack(alignment: .leading, spacing: 8) {
                tipRow("Print or share this PDF directly with your accountant")
                tipRow("The mileage log meets IRS documentation requirements")
                tipRow("Review the CPA Notes section for discussion points")
                tipRow("Keep receipts for expenses over $250")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.incomeGreen)
                .font(.caption)
                .accessibilityHidden(true)
            Text(text)
                .font(.caption)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
    
    // MARK: - Generate Report Action
    
    private func generateReport() {
        isGenerating = true
        
        // Capture values for the task
        let currentDateRange = dateRange
        let currentTitle = reportTitle
        let currentIncludePersonal = includePersonal
        let currentIncludeMileage = includeMileage
        let currentIncludeInvoices = includeInvoices
        let currentIncludeDetailedTransactions = includeDetailedTransactions
        let currentIncludeTaxEstimates = includeTaxEstimates
        let currentBusinessName = businessProfile?.businessName
        let currentBusinessAddress = businessProfile?.formattedAddress
        let currentTransactions = transactions
        let currentMileageTrips = mileageTrips
        let currentInvoices = invoices
        let currentTaxSettings = taxSettings
        let currentBusinessProfile = businessProfile
        
        Task { @MainActor in
            let config = ReportConfiguration(
                title: currentTitle,
                dateRange: currentDateRange,
                includePersonal: currentIncludePersonal,
                includeMileage: currentIncludeMileage,
                includeInvoices: currentIncludeInvoices,
                includeDetailedTransactions: currentIncludeDetailedTransactions,
                includeTaxEstimates: currentIncludeTaxEstimates,
                businessName: currentBusinessName,
                businessAddress: currentBusinessAddress,
                ein: nil,
                preparedFor: nil
            )
            
            let result = ComprehensiveReportService.shared.generateComprehensiveReport(
                config: config,
                transactions: Array(currentTransactions),
                mileageTrips: Array(currentMileageTrips),
                invoices: Array(currentInvoices),
                taxSettings: currentTaxSettings,
                businessProfile: currentBusinessProfile
            )
            
            isGenerating = false
            
            switch result {
            case .success(let data):
                generatedPDF = data
                HapticService.play(.success)
                showingShareSheet = true
                
            case .failure(let error):
                errorMessage = error.localizedDescription
                HapticService.play(.error)
                showingError = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ComprehensiveReportView()
        .modelContainer(for: [
            Transaction.self,
            MileageTrip.self,
            Invoice.self,
            TaxSettings.self,
            BusinessProfile.self
        ])
}
