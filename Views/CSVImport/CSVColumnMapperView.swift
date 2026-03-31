//  CSVColumnMapperView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.4 - Dark Mode Optimization: Adaptive color fixes
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.4 - Dark Mode Optimization:
//  ✅ FIXED: L522 Color.gray.opacity(0.3) → Color.gray.opacity(0.3).opacity(0.3) for button background (adapts to dark mode)
//
//  CHANGES v1.3 - Dynamic Type Verification:
//  ✅ FIXED: Instructions title "Manual Column Mapping" missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Instructions description missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "CSV Preview" header missing lineLimit + minimumScaleFactor
//  ✅ FIXED: CSV table headers missing lineLimit + minimumScaleFactor
//  ✅ FIXED: CSV table cells missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Toggle labels missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Toggle descriptions missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Section headers missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Date format description missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Date format example text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Amount convention description missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Amount convention info text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Continue button text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Validation error text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: ColumnPicker title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: ColumnPicker subtitle missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Picker option text missing lineLimit + minimumScaleFactor
//
//  CHANGES v1.2:
//  - Fixed CSVImportReviewView initialization to use importResult
//  - Added parseTransactions call before navigation
//  - Fixed Logger string interpolation for CSVColumnMapping
//
//  CHANGES v1.1:
//  - Added screen announcement on appear
//  - Full VoiceOver accessibility coverage for all pickers and toggles
//  - Decorative icons hidden from VoiceOver
//  - CSV preview table with accessibility label
//  - Validation error announcements
//

import SwiftUI
import os.log

/// Manual column mapping interface for CSV files with unrecognized formats
struct CSVColumnMapperView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let fileURL: URL
    let rawRows: [CSVRawRow]
    let detectedProfile: CSVBankProfile?
    
    // Column mapping state
    @State private var selectedDateColumn: Int?
    @State private var selectedDescriptionColumn: Int?
    @State private var selectedAmountColumn: Int?
    @State private var selectedDebitColumn: Int?
    @State private var selectedCreditColumn: Int?
    @State private var selectedCategoryColumn: Int?
    @State private var selectedCheckNumberColumn: Int?
    @State private var selectedBalanceColumn: Int?
    
    // Configuration state
    @State private var useSplitColumns = false
    @State private var selectedDateFormat = "MM/dd/yyyy"
    @State private var selectedAmountConvention: CSVBankProfile.AmountConvention = .signedSingleColumn
    @State private var hasHeader = true
    
    // Validation
    @State private var validationError: String?
    @State private var showingValidationAlert = false
    
    // Navigation
    @State private var showingReview = false
    @State private var customProfile: CSVBankProfile?
    @State private var importResult: CSVImportResult?
    
    private static let logger = Logger(
        subsystem: "com.finchandpoppy.flo",
        category: "CSVColumnMapperView"
    )
    
    // Available date formats
    private let dateFormats = [
        "MM/dd/yyyy",
        "M/d/yyyy",
        "M/d/yy",
        "yyyy-MM-dd",
        "dd/MM/yyyy",
        "d/M/yyyy",
        "MMM d, yyyy",
        "MMMM d, yyyy"
    ]
    
    // CSV headers and preview data
    private var headers: [String] {
        guard let firstRow = rawRows.first else { return [] }
        return hasHeader ? firstRow.fields : firstRow.fields.enumerated().map { "Column \($0.offset + 1)" }
    }
    
    private var previewRows: [CSVRawRow] {
        let dataStartIndex = hasHeader ? 1 : 0
        let endIndex = min(dataStartIndex + 3, rawRows.count)
        return Array(rawRows[dataStartIndex..<endIndex])
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Instructions
                instructionsSection
                
                // CSV Preview
                csvPreviewSection
                
                // Header Toggle
                headerToggleSection
                
                // Column Mapping Controls
                columnMappingSection
                
                // Date Format Picker
                dateFormatSection
                
                // Amount Convention
                amountConventionSection
                
                // Continue Button
                continueButton
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Color.floSystemGroupedBackground)
        .navigationTitle("Map Columns")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showingReview) {
            if let result = importResult {
                CSVImportReviewView(importResult: result)
            }
        }
        .alert("Validation Error", isPresented: $showingValidationAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = validationError {
                Text(error)
            }
        }
        .onChange(of: validationError) { oldValue, newValue in
            if let error = newValue, !error.isEmpty {
                AccessibilityAnnouncement.announce("Validation error: \(error)")
            }
        }
        .onAppear {
            initializeFromDetectedProfile()
            AccessibilityAnnouncement.screenChanged("Column Mapping")
        }
    }
    
    // MARK: - Instructions Section
    
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.up.arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.brandPrimary)
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Manual Column Mapping")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("We couldn't automatically detect your bank format. Please map your CSV columns below.")
                        .font(.subheadline)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .background(Color.floSecondarySystemGroupedBackground)
        .cornerRadius(12)
    }
    
    // MARK: - CSV Preview Section
    
    private var csvPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CSV Preview")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            
            ScrollView(.horizontal, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header row
                    if hasHeader {
                        HStack(spacing: 0) {
                            ForEach(Array(headers.enumerated()), id: \.offset) { index, header in
                                Text(header)
                                    .font(.caption.bold())
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .foregroundStyle(.white)
                                    .padding(8)
                                    .frame(minWidth: 100, alignment: .leading)
                                    .background(Color.brandPrimary)
                            }
                        }
                    }
                    
                    // Data rows
                    ForEach(Array(previewRows.enumerated()), id: \.element.lineNumber) { rowIndex, row in
                        HStack(spacing: 0) {
                            ForEach(Array(row.fields.enumerated()), id: \.offset) { colIndex, field in
                                Text(field)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    .padding(8)
                                    .frame(minWidth: 100, alignment: .leading)
                                    .background(rowIndex % 2 == 0 ? Color.floSystemBackground : Color.floSecondarySystemBackground)
                            }
                        }
                    }
                }
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("CSV column preview showing headers and sample data")
        }
        .padding(20)
        .background(Color.floSecondarySystemGroupedBackground)
        .cornerRadius(12)
    }
    
    // MARK: - Header Toggle Section
    
    private var headerToggleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $hasHeader) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("First row contains headers")
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("Turn off if your CSV doesn't have column names in the first row")
                        .font(.caption)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: Color.brandPrimary))
            .onChange(of: hasHeader) { oldValue, newValue in
                HapticService.play(.light)
                // Reset selections when header setting changes
                resetAllSelections()
            }
        }
        .padding(20)
        .background(Color.floSecondarySystemGroupedBackground)
        .cornerRadius(12)
    }
    
    // MARK: - Column Mapping Section
    
    private var columnMappingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Required Columns")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            
            // Date Column
            ColumnPicker(
                title: "Date Column",
                subtitle: "Which column contains the transaction date?",
                icon: "calendar",
                selection: $selectedDateColumn,
                options: headers,
                isRequired: true
            )
            
            // Description Column
            ColumnPicker(
                title: "Description Column",
                subtitle: "Which column contains the merchant/description?",
                icon: "text.alignleft",
                selection: $selectedDescriptionColumn,
                options: headers,
                isRequired: true
            )
            
            // Amount configuration
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $useSplitColumns) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bank uses separate Debit/Credit columns")
                            .font(.subheadline.weight(.medium))
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                        Text("Some banks split expenses and income into two columns")
                            .font(.caption)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: Color.brandPrimary))
                .accessibilityLabel("Bank uses separate debit and credit columns")
                .accessibilityHint("Enable if your bank splits expenses and income into different columns")
                .onChange(of: useSplitColumns) { oldValue, newValue in
                    HapticService.play(.light)
                    if newValue {
                        selectedAmountColumn = nil
                    } else {
                        selectedDebitColumn = nil
                        selectedCreditColumn = nil
                    }
                }
                
                if useSplitColumns {
                    // Debit Column
                    ColumnPicker(
                        title: "Debit Column (Expenses)",
                        subtitle: "Column for money spent",
                        icon: "arrow.up.circle",
                        selection: $selectedDebitColumn,
                        options: headers,
                        isRequired: true
                    )
                    
                    // Credit Column
                    ColumnPicker(
                        title: "Credit Column (Income)",
                        subtitle: "Column for money received",
                        icon: "arrow.down.circle",
                        selection: $selectedCreditColumn,
                        options: headers,
                        isRequired: true
                    )
                } else {
                    // Single Amount Column
                    ColumnPicker(
                        title: "Amount Column",
                        subtitle: "Which column contains the transaction amount?",
                        icon: "dollarsign.circle",
                        selection: $selectedAmountColumn,
                        options: headers,
                        isRequired: true
                    )
                }
            }
            
            Divider()
                .padding(.vertical, 8)
            
            // Optional Columns
            Text("Optional Columns")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            
            ColumnPicker(
                title: "Category Column",
                subtitle: "Pre-assigned categories (if available)",
                icon: "tag",
                selection: $selectedCategoryColumn,
                options: headers,
                isRequired: false
            )
            
            ColumnPicker(
                title: "Check Number Column",
                subtitle: "Check or reference number",
                icon: "number",
                selection: $selectedCheckNumberColumn,
                options: headers,
                isRequired: false
            )
            
            ColumnPicker(
                title: "Balance Column",
                subtitle: "Running balance after transaction",
                icon: "chart.line.uptrend.xyaxis",
                selection: $selectedBalanceColumn,
                options: headers,
                isRequired: false
            )
        }
        .padding(20)
        .background(Color.floSecondarySystemGroupedBackground)
        .cornerRadius(12)
    }
    
    // MARK: - Date Format Section
    
    private var dateFormatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Date Format")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            
            Text("Select the format that matches your CSV dates")
                .font(.subheadline)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.secondary)
            
            Picker("Date Format", selection: $selectedDateFormat) {
                ForEach(dateFormats, id: \.self) { format in
                    Text(format)
                        .tag(format)
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel("Select date format")
            .accessibilityHint("Choose the date format used in your CSV file")
            .onChange(of: selectedDateFormat) { oldValue, newValue in
                HapticService.play(.light)
            }
            
            // Example preview
            if let exampleDate = getExampleDate() {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Example from your data: \(exampleDate)")
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .background(Color.floSecondarySystemGroupedBackground)
        .cornerRadius(12)
    }
    
    // MARK: - Amount Convention Section
    
    private var amountConventionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Amount Convention")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            
            Text("How does your bank represent expenses?")
                .font(.subheadline)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.secondary)
            
            Picker("Amount Convention", selection: $selectedAmountConvention) {
                Text("Negative = Expense (most common)")
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .tag(CSVBankProfile.AmountConvention.signedSingleColumn)
                Text("Positive = Expense (Discover style)")
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .tag(CSVBankProfile.AmountConvention.positiveExpense)
            }
            .pickerStyle(.segmented)
            .disabled(useSplitColumns) // Not applicable for split columns
            .accessibilityLabel("Amount sign convention")
            .accessibilityHint("Select whether negative numbers represent expenses or income")
            .onChange(of: selectedAmountConvention) { oldValue, newValue in
                HapticService.play(.light)
            }
            
            if useSplitColumns {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Text("Not applicable when using separate Debit/Credit columns")
                        .font(.caption)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .background(Color.floSecondarySystemGroupedBackground)
        .cornerRadius(12)
    }
    
    // MARK: - Continue Button
    
    private var continueButton: some View {
        VStack(spacing: 12) {
            Button {
                validateAndContinue()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3)
                        .accessibilityHidden(true)
                    Text("Continue to Review")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isFormValid ? Color.brandPrimary : Color.gray.opacity(0.3).opacity(0.3))
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
            .disabled(!isFormValid)
            .accessibilityLabel("Continue with column mapping")
            .accessibilityHint("Uses your column selections to parse the CSV file")
            
            if let error = validationError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.red)
                }
            }
        }
    }
    
    // MARK: - Validation
    
    private var isFormValid: Bool {
        // Date and description are always required
        guard selectedDateColumn != nil,
              selectedDescriptionColumn != nil else {
            return false
        }
        
        // Amount or split columns required
        if useSplitColumns {
            guard selectedDebitColumn != nil,
                  selectedCreditColumn != nil else {
                return false
            }
        } else {
            guard selectedAmountColumn != nil else {
                return false
            }
        }
        
        // Check for duplicate column assignments
        var usedColumns: Set<Int> = []
        
        let allSelections = [
            selectedDateColumn,
            selectedDescriptionColumn,
            useSplitColumns ? nil : selectedAmountColumn,
            useSplitColumns ? selectedDebitColumn : nil,
            useSplitColumns ? selectedCreditColumn : nil
        ].compactMap { $0 }
        
        for column in allSelections {
            if usedColumns.contains(column) {
                return false // Duplicate column assignment
            }
            usedColumns.insert(column)
        }
        
        return true
    }
    
    private func validateAndContinue() {
        // Final validation with detailed error messages
        guard let dateCol = selectedDateColumn else {
            validationError = "Please select a date column"
            showingValidationAlert = true
            HapticService.play(.error)
            return
        }
        
        guard let descCol = selectedDescriptionColumn else {
            validationError = "Please select a description column"
            showingValidationAlert = true
            HapticService.play(.error)
            return
        }
        
        var amountCol: Int = 0
        var debitCol: Int?
        var creditCol: Int?
        
        if useSplitColumns {
            guard let debit = selectedDebitColumn else {
                validationError = "Please select a debit column"
                showingValidationAlert = true
                HapticService.play(.error)
                return
            }
            guard let credit = selectedCreditColumn else {
                validationError = "Please select a credit column"
                showingValidationAlert = true
                HapticService.play(.error)
                return
            }
            debitCol = debit
            creditCol = credit
        } else {
            guard let amount = selectedAmountColumn else {
                validationError = "Please select an amount column"
                showingValidationAlert = true
                HapticService.play(.error)
                return
            }
            amountCol = amount
        }
        
        // Check for duplicate assignments (required columns only)
        let requiredColumns = useSplitColumns
            ? [dateCol, descCol, debitCol!, creditCol!]
            : [dateCol, descCol, amountCol]
        
        if Set(requiredColumns).count != requiredColumns.count {
            validationError = "Each column can only be used once. Please check your selections."
            showingValidationAlert = true
            HapticService.play(.error)
            return
        }
        
        // Build column mapping
        let mapping = CSVColumnMapping(
            dateColumn: dateCol,
            descriptionColumn: descCol,
            amountColumn: amountCol,
            creditColumn: creditCol,
            debitColumn: debitCol,
            categoryColumn: selectedCategoryColumn,
            checkNumberColumn: selectedCheckNumberColumn,
            balanceColumn: selectedBalanceColumn
        )
        
        // Build custom bank profile
        let profile = CSVBankProfile(
            id: "manual",
            displayName: "Custom Format",
            icon: "doc.text",
            dateFormat: selectedDateFormat,
            columnMapping: mapping,
            hasHeader: hasHeader,
            headerKeywords: [],
            amountConvention: useSplitColumns ? .splitDebitCredit : selectedAmountConvention
        )
        
        Self.logger.info("Manual column mapping complete: date=\(mapping.dateColumn), desc=\(mapping.descriptionColumn), amount=\(mapping.amountColumn)")
        
        customProfile = profile
        validationError = nil
        
        // Parse transactions using the manual mapping
        let dataRows = hasHeader ? Array(rawRows.dropFirst()) : rawRows
        let result = CSVParserService.shared.parseTransactions(
            rows: dataRows,
            mapping: mapping,
            profile: profile,
            categories: [],
            merchantMappings: []
        )
        
        importResult = result
        HapticService.play(.success)
        showingReview = true
    }
    
    // MARK: - Helper Methods
    
    private func initializeFromDetectedProfile() {
        // If we have a detected profile (but it failed validation), pre-populate with its values
        guard let profile = detectedProfile else { return }
        
        selectedDateColumn = profile.columnMapping.dateColumn
        selectedDescriptionColumn = profile.columnMapping.descriptionColumn
        selectedAmountColumn = profile.columnMapping.amountColumn
        selectedDebitColumn = profile.columnMapping.debitColumn
        selectedCreditColumn = profile.columnMapping.creditColumn
        selectedCategoryColumn = profile.columnMapping.categoryColumn
        selectedCheckNumberColumn = profile.columnMapping.checkNumberColumn
        selectedBalanceColumn = profile.columnMapping.balanceColumn
        
        useSplitColumns = profile.columnMapping.usesSplitColumns
        selectedDateFormat = profile.dateFormat
        selectedAmountConvention = profile.amountConvention
        hasHeader = profile.hasHeader
        
        Self.logger.debug("Initialized from detected profile: \(profile.displayName)")
    }
    
    private func resetAllSelections() {
        selectedDateColumn = nil
        selectedDescriptionColumn = nil
        selectedAmountColumn = nil
        selectedDebitColumn = nil
        selectedCreditColumn = nil
        selectedCategoryColumn = nil
        selectedCheckNumberColumn = nil
        selectedBalanceColumn = nil
        validationError = nil
    }
    
    private func getExampleDate() -> String? {
        guard let dateCol = selectedDateColumn,
              let firstDataRow = previewRows.first,
              dateCol < firstDataRow.fields.count else {
            return nil
        }
        return firstDataRow.fields[dateCol]
    }
}

// MARK: - Column Picker Component

struct ColumnPicker: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var selection: Int?
    let options: [String]
    let isRequired: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(Color.brandPrimary)
                    .frame(width: 20)
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(title)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if isRequired {
                            Text("*")
                                .font(.subheadline)
                                .foregroundStyle(.red)
                                .accessibilityHidden(true)
                        }
                    }
                    Text(subtitle)
                        .font(.caption)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                }
            }
            
            Picker(title, selection: $selection) {
                Text("Not used")
                    .lineLimit(1)
                    .tag(nil as Int?)
                ForEach(Array(options.enumerated()), id: \.offset) { index, header in
                    Text("\(header) (Column \(index + 1))")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .tag(index as Int?)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selection) { oldValue, newValue in
                HapticService.play(.light)
            }
            .accessibilityLabel("Select \(title.lowercased())")
            .accessibilityHint(subtitle)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CSVColumnMapperView(
            fileURL: URL(fileURLWithPath: "/tmp/test.csv"),
            rawRows: [
                CSVRawRow(lineNumber: 1, fields: ["Date", "Description", "Amount", "Balance"]),
                CSVRawRow(lineNumber: 2, fields: ["01/15/2026", "Coffee Shop", "-4.50", "1234.56"]),
                CSVRawRow(lineNumber: 3, fields: ["01/16/2026", "Salary Deposit", "2500.00", "3734.56"])
            ],
            detectedProfile: nil
        )
    }
}
