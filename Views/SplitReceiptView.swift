//  SplitReceiptView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.2 - Accessibility audit (Sprint 7)
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v3.2:
//  ✅ Screen change announcement on appear
//  ✅ Split preview progress bars get accessibility values
//  ✅ AnimatedLineItemRow selection traits added
//  ✅ Fixed garbled multiplication character in line item quantity display
//  ✅ Fixed garbled UTF-8 in print statements
//
//  UI for splitting receipts between business and personal expenses
//
//  ENHANCEMENTS v3.0:
//  - Animated percentage slider with haptic feedback
//  - Line item selection animations with checkmark bounce
//  - Split preview with animated bars
//  - Mode picker with haptic feedback
//  - Quick percentage buttons with press states
//  - Save confirmation animation
//  - Smooth transitions between split modes
//

import SwiftUI
import SwiftData

struct SplitReceiptView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var receipt: ReceiptData
    
    @State private var businessPercentage: Double
    @State private var splitNotes: String
    @State private var selectedLineItems: Set<UUID> = []
    @State private var splitMode: SplitMode = .percentage
    @State private var businessAmount: Double = 0
    
    // Animation States
    @State private var headerOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @State private var previewOpacity: Double = 0
    @State private var saveButtonScale: CGFloat = 1.0
    @State private var businessBarWidth: CGFloat = 0
    @State private var personalBarWidth: CGFloat = 0
    @State private var quickButtonPressed: Int? = nil
    @State private var showSavedCheck = false
    
    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }
    
    // Helper to format currency for accessibility
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
    
    init(receipt: ReceiptData) {
        self.receipt = receipt
        _businessPercentage = State(initialValue: receipt.businessPercentage)
        _splitNotes = State(initialValue: receipt.splitNotes ?? "")
        
        let preselected = Set(receipt.lineItems
            .filter { $0.isBusiness }
            .map { $0.id })
        _selectedLineItems = State(initialValue: preselected)
        
        if !preselected.isEmpty && receipt.hasLineItems {
            _splitMode = State(initialValue: .lineItems)
        }
        
        _businessAmount = State(initialValue: receipt.totalAmount * (receipt.businessPercentage / 100.0))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Receipt Summary
                Section("Receipt Details") {
                    LabeledContent("Merchant", value: receipt.merchantName)
                    LabeledContent("Date") {
                        Text(receipt.date, style: .date)
                    }
                    LabeledContent("Total") {
                        Text(receipt.totalAmount, format: .currency(code: currencyCode))
                            .fontWeight(.semibold)
                    }
                }
                .opacity(headerOpacity)
                
                // Split Mode Picker
                Section("Split Method") {
                    Picker("Method", selection: $splitMode) {
                        Text("Percentage").tag(SplitMode.percentage)
                        Text("Line Items").tag(SplitMode.lineItems)
                        Text("Fixed Amount").tag(SplitMode.fixedAmount)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Select split method: Percentage, Line Items, or Fixed Amount")
                    .onChange(of: splitMode) { _, _ in
                        HapticService.shared.selection()
                    }
                }
                .opacity(headerOpacity)
                
                // Split Configuration
                Group {
                    switch splitMode {
                    case .percentage:
                        percentageSplitSection
                    case .lineItems:
                        lineItemsSplitSection
                    case .fixedAmount:
                        fixedAmountSplitSection
                    }
                }
                .opacity(contentOpacity)
                .animation(.easeInOut(duration: 0.2), value: splitMode)
                
                // Split Preview
                splitPreviewSection
                    .opacity(previewOpacity)
                
                // Notes
                Section("Notes") {
                    TextField("Add notes about this split...", text: $splitNotes, axis: .vertical)
                        .lineLimit(3...6)
                        .textInputAutocapitalization(.sentences)
                }
                .opacity(contentOpacity)
            }
            .navigationTitle("Split Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
  
                        HapticService.play(.medium)
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSplit()
                    }
                    .fontWeight(.semibold)
                    .disabled(isSaveDisabled)
                    .scaleEffect(saveButtonScale)
                }
            }
            .onAppear {
                animateEntrance()
                AccessibilityAnnouncement.screenChanged("Split receipt")
            }
            .onChange(of: splitMode) { oldMode, newMode in
                handleModeChange(from: oldMode, to: newMode)
            }
            .onChange(of: businessAmount, initial: false) { oldValue, newValue in
                if newValue < 0 {
                    businessAmount = 0
                } else if newValue > receipt.totalAmount {
                    businessAmount = receipt.totalAmount
                }
            }
        }
    }
    
    // MARK: - Animations
    
    private func animateEntrance() {
        withAnimation(.easeOut(duration: 0.3)) {
            headerOpacity = 1.0
        }
        
        withAnimation(.easeOut(duration: 0.3).delay(0.1)) {
            contentOpacity = 1.0
        }
        
        withAnimation(.easeOut(duration: 0.3).delay(0.2)) {
            previewOpacity = 1.0
        }
        
        // Animate preview bars
        updatePreviewBars()
    }
    
    private func updatePreviewBars() {
        let businessRatio = calculatedBusinessAmount / max(receipt.totalAmount, 1)
        let personalRatio = calculatedPersonalAmount / max(receipt.totalAmount, 1)
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            businessBarWidth = CGFloat(businessRatio)
            personalBarWidth = CGFloat(personalRatio)
        }
    }
    
    // MARK: - Percentage Split
    
    private var percentageSplitSection: some View {
        Section {
            VStack(spacing: 16) {
                Text("\(Int(businessPercentage))% Business")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(AppConstants.primaryColor)
                    .contentTransition(.numericText())
                
                Slider(value: $businessPercentage, in: 0...100, step: 5)
                    .tint(AppConstants.primaryColor)
                    .accessibilityLabel("Business percentage slider: \(Int(businessPercentage)) percent")
                    .onChange(of: businessPercentage) { _, _ in
                        HapticService.shared.selection()
                        updatePreviewBars()
                    }
                
                HStack {
                    Text("0%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("50%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("100%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Quick percentage buttons
                HStack(spacing: 12) {
                    QuickPercentButton(value: 25, isPressed: quickButtonPressed == 25) {
                        setQuickPercentage(25)
                    }
                    QuickPercentButton(value: 50, isPressed: quickButtonPressed == 50) {
                        setQuickPercentage(50)
                    }
                    QuickPercentButton(value: 75, isPressed: quickButtonPressed == 75) {
                        setQuickPercentage(75)
                    }
                    QuickPercentButton(value: 100, isPressed: quickButtonPressed == 100) {
                        setQuickPercentage(100)
                    }
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Business Percentage")
        } footer: {
            Text("Adjust the slider to set what percentage of this receipt is for business expenses.")
        }
    }
    
    private func setQuickPercentage(_ value: Int) {

        HapticService.play(.medium)
        
        quickButtonPressed = value
        
        withAnimation(FLOAnimation.quick) {
            businessPercentage = Double(value)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            quickButtonPressed = nil
        }
        
        updatePreviewBars()
    }
    
    // MARK: - Line Items Split
    
    private var lineItemsSplitSection: some View {
        Section {
            if receipt.hasLineItems {
                ForEach(receipt.lineItems, id: \.id) { item in
                    AnimatedLineItemRow(
                        item: item,
                        isSelected: selectedLineItems.contains(item.id),
                        currencyCode: currencyCode
                    ) {
                        toggleLineItem(item.id)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Text("No line items detected")
                        .foregroundStyle(.secondary)
                        .italic()
                    
                    Button {

                        HapticService.play(.medium)
                        print("🔗 Add line items manually")
                    } label: {
                        Label("Add Line Items Manually", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(AppConstants.primaryColor)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        } header: {
            Text("Select Business Items")
        } footer: {
            if receipt.hasLineItems {
                Text("Choose which items are business expenses. The percentage will update automatically.")
            } else {
                Text("Add individual items to split by line item instead of percentage.")
            }
        }
    }
    
    // MARK: - Fixed Amount Split
    
    private var fixedAmountSplitSection: some View {
        Section {
            HStack {
                Text("Business Amount")
                Spacer()
                TextField("Amount", value: $businessAmount, format: .currency(code: currencyCode))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
                    .accessibilityLabel("Business amount: \(formatCurrency(businessAmount))")
                    .onChange(of: businessAmount) { _, _ in
                        updatePreviewBars()
                    }
            }
            
            HStack {
                Text("Personal Amount")
                Spacer()
                Text(receipt.totalAmount - businessAmount, format: .currency(code: currencyCode))
                    .foregroundStyle(.secondary)
            }
        } footer: {
            if businessAmount > receipt.totalAmount {
                Text("Amount must be between \(formatCurrency(0)) and \(formatCurrency(receipt.totalAmount))")
                    .foregroundStyle(.red)
            }
        }
    }
    
    // MARK: - Split Preview Section
    
    private var splitPreviewSection: some View {
        Section("Split Preview") {
            VStack(spacing: 16) {
                // Animated progress bars
                GeometryReader { geometry in
                    VStack(spacing: 8) {
                        // Business bar
                        HStack(spacing: 8) {
                            Text("Business")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 60, alignment: .leading)
                            
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 12)
                                
                                Rectangle()
                                    .fill(AppConstants.primaryColor)
                                    .frame(width: max(4, (geometry.size.width - 130) * businessBarWidth), height: 12)
                            }
                            .cornerRadius(6)
                            .accessibilityHidden(true)
                            
                            Text(formatCurrency(calculatedBusinessAmount))
                                .font(.caption)
                                .fontWeight(.medium)
                                .frame(width: 60, alignment: .trailing)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Business: \(formatCurrency(calculatedBusinessAmount))")
                        .accessibilityValue("\(Int(businessBarWidth * 100)) percent")
                        
                        // Personal bar
                        HStack(spacing: 8) {
                            Text("Personal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 60, alignment: .leading)
                            
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 12)
                                
                                Rectangle()
                                    .fill(Color.orange)
                                    .frame(width: max(4, (geometry.size.width - 130) * personalBarWidth), height: 12)
                            }
                            .cornerRadius(6)
                            .accessibilityHidden(true)
                            
                            Text(formatCurrency(calculatedPersonalAmount))
                                .font(.caption)
                                .fontWeight(.medium)
                                .frame(width: 60, alignment: .trailing)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Personal: \(formatCurrency(calculatedPersonalAmount))")
                        .accessibilityValue("\(Int(personalBarWidth * 100)) percent")
                    }
                }
                .frame(minHeight: 44)
                
                Divider()
                
                // Summary amounts
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Business", systemImage: "briefcase.fill")
                            .font(.subheadline)
                            .foregroundStyle(AppConstants.primaryColor)
                        
                        Text(calculatedBusinessAmount, format: .currency(code: currencyCode))
                            .font(.title3)
                            .fontWeight(.bold)
                            .contentTransition(.numericText())
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Label("Personal", systemImage: "person.fill")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                        
                        Text(calculatedPersonalAmount, format: .currency(code: currencyCode))
                            .font(.title3)
                            .fontWeight(.bold)
                            .contentTransition(.numericText())
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Computed Properties
    
    private var calculatedBusinessAmount: Double {
        switch splitMode {
        case .percentage:
            return receipt.totalAmount * (businessPercentage / 100.0)
        case .lineItems:
            return receipt.lineItems
                .filter { selectedLineItems.contains($0.id) }
                .reduce(0) { $0 + $1.totalAmount }
        case .fixedAmount:
            return min(max(businessAmount, 0), receipt.totalAmount)
        }
    }
    
    private var calculatedPersonalAmount: Double {
        receipt.totalAmount - calculatedBusinessAmount
    }
    
    private var isSaveDisabled: Bool {
        if splitMode == .fixedAmount {
            return businessAmount < 0 || businessAmount > receipt.totalAmount
        }
        return false
    }
    
    // MARK: - State Management
    
    private func handleModeChange(from oldMode: SplitMode, to newMode: SplitMode) {
        switch newMode {
        case .percentage:
            if receipt.totalAmount > 0 {
                businessPercentage = (calculatedBusinessAmount / receipt.totalAmount) * 100
            }
            
        case .lineItems:
            break
            
        case .fixedAmount:
            businessAmount = calculatedBusinessAmount
        }
        
        updatePreviewBars()
        
        #if DEBUG
        print("🔗 Split mode changed: \(oldMode) → \(newMode)")
        print("   Business: \(formatCurrency(calculatedBusinessAmount))")
        print("   Percentage: \(Int(businessPercentage))%")
        #endif
    }
    
    // MARK: - Actions
    
    private func toggleLineItem(_ id: UUID) {

        HapticService.play(.medium)
        
        if selectedLineItems.contains(id) {
            selectedLineItems.remove(id)
        } else {
            selectedLineItems.insert(id)
        }
        
        let businessTotal = receipt.lineItems
            .filter { selectedLineItems.contains($0.id) }
            .reduce(0) { $0 + $1.totalAmount }
        
        if receipt.totalAmount > 0 {
            businessPercentage = (businessTotal / receipt.totalAmount) * 100
        }
        
        updatePreviewBars()
    }
    
    private func saveSplit() {
        // Button press animation
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            saveButtonScale = 0.9
        }
        

        HapticService.play(.medium)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                saveButtonScale = 1.0
            }
        }
        
        receipt.businessPercentage = businessPercentage
        receipt.splitNotes = splitNotes.isEmpty ? nil : splitNotes
        receipt.modifiedDate = Date()
        
        if splitMode == .lineItems {
            for index in receipt.lineItems.indices {
                receipt.lineItems[index].isBusiness = selectedLineItems.contains(receipt.lineItems[index].id)
            }
        }
        
        do {
            try modelContext.save()
            
            // Success haptic
            HapticService.shared.success()
            
            #if DEBUG
            print("🔗 Receipt split saved:")
            print("   Mode: \(splitMode)")
            print("   Business: \(formatCurrency(calculatedBusinessAmount)) (\(Int(businessPercentage))%)")
            print("   Personal: \(formatCurrency(calculatedPersonalAmount))")
            #endif
            
            dismiss()
            
        } catch {
            HapticService.shared.error()
            
            #if DEBUG
            print("❌ Failed to save split: \(error)")
            #endif
        }
    }
}

// MARK: - Quick Percent Button

private struct QuickPercentButton: View {
    let value: Int
    let isPressed: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("\(value)%")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(AppConstants.primaryColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppConstants.primaryColor.opacity(0.1))
                )
                .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.15, dampingFraction: 0.6), value: isPressed)
    }
}

// MARK: - Animated Line Item Row

private struct AnimatedLineItemRow: View {
    let item: ReceiptLineItem
    let isSelected: Bool
    let currencyCode: String
    let onToggle: () -> Void
    
    @State private var checkmarkScale: CGFloat = 1.0
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
    
    var body: some View {
        Button(action: {
            onToggle()
            
            if !isSelected {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                    checkmarkScale = 1.2
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        checkmarkScale = 1.0
                    }
                }
            }
        }) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AppConstants.primaryColor : .gray)
                    .font(.title3)
                    .scaleEffect(checkmarkScale)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.itemDescription)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    
                    if item.quantity > 1 {
                        Text("\(item.quantity) × \(item.amount, format: .currency(code: currencyCode))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Text(item.totalAmount, format: .currency(code: currencyCode))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.itemDescription), \(formatCurrency(item.totalAmount)), \(isSelected ? "selected as business" : "select for business")")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Split Mode

enum SplitMode {
    case percentage
    case lineItems
    case fixedAmount
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: ReceiptData.self,
        configurations: config
    )
    
    let _ = {
        let context = container.mainContext
        
        let receipt = ReceiptData(
            merchantName: "Costco",
            totalAmount: 127.45,
            date: Date()
        )
        
        receipt.lineItems = [
            ReceiptLineItem(
                description: "Office Paper",
                amount: 24.99,
                quantity: 1,
                isBusiness: true
            ),
            ReceiptLineItem(
                description: "Pens (Pack of 12)",
                amount: 12.99,
                quantity: 12,
                isBusiness: true
            ),
            ReceiptLineItem(
                description: "Groceries",
                amount: 89.47,
                quantity: 1,
                isBusiness: false
            )
        ]
        
        context.insert(receipt)
    }()
    
    let context = container.mainContext
    let descriptor = FetchDescriptor<ReceiptData>()
    let receipts = try! context.fetch(descriptor)
    let receipt = receipts.first!
    
    SplitReceiptView(receipt: receipt)
        .modelContainer(container)
}
