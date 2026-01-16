//  ReceiptManagementCard.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.0 - Enhanced with Haptics & Micro-Animations
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  Dashboard card showing receipt scanning status and actionable insights
//
//  ENHANCEMENTS v3.0:
//  - Animated stat pills with staggered entrance
//  - Haptic feedback on scan button and view all actions
//  - Pulsing attention indicator for receipts needing review
//  - Progress counter animations for stats
//  - Card press states with scale effects
//  - Empty state bounce animation
//  - Smooth filter transitions in receipt list
//

import SwiftUI
import SwiftData

struct ReceiptManagementCard: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var receipts: [ReceiptData]
    
    @State private var showingReceiptScanner = false
    @State private var showingReceiptList = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    // Animation States
    @State private var headerOpacity: Double = 0
    @State private var statsVisible = false
    @State private var emptyStateScale: CGFloat = 0.8
    @State private var scanButtonPressed = false
    @State private var viewAllPressed = false
    @State private var attentionPulse = false
    
    // Get current locale currency code
    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }
    
    // Helper to format currency for accessibility labels
    private func taxDeductibleAccessibilityLabel(amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        let formattedAmount = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
        return "Tax deductible amount: \(formattedAmount)"
    }
    
    private var stats: ReceiptStats {
        let total = receipts.count
        let matched = receipts.filter {
            $0.matchStatus == .automaticMatch || $0.matchStatus == .manualMatch
        }.count
        let unmatched = receipts.filter { $0.matchStatus == .unmatched }.count
        let needsAttention = receipts.filter { $0.needsAttention }.count
        
        let totalDeductible = receipts
            .filter { $0.isTaxDeductible }
            .reduce(0) { $0 + $1.businessAmount }
        
        return ReceiptStats(
            total: total,
            matched: matched,
            unmatched: unmatched,
            needsAttention: needsAttention,
            totalDeductible: totalDeductible
        )
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "doc.text.image")
                    .font(.title3)
                    .foregroundStyle(AppConstants.primaryColor)
                    .symbolEffect(.bounce, options: .speed(0.5), value: headerOpacity > 0)
                
                Text("Receipt Management")
                    .font(.headline)
                
                Spacer()
                
                Button {
                   
                    HapticService.play(.medium)
                    
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        scanButtonPressed = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                            scanButtonPressed = false
                        }
                    }
                    
                    showingReceiptScanner = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(AppConstants.primaryColor)
                        .scaleEffect(scanButtonPressed ? 0.85 : 1.0)
                }
                .accessibilityLabel("Scan new receipt")
            }
            .opacity(headerOpacity)
            
            if stats.total == 0 {
                // Empty State
                emptyStateView
            } else {
                // Stats View
                statsView
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .onAppear {
            animateEntrance()
        }
        .sheet(isPresented: $showingReceiptScanner) {
            SmartReceiptScanningView()
        }
        .sheet(isPresented: $showingReceiptList) {
            ReceiptListView()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Animations
    
    private func animateEntrance() {
        withAnimation(.easeOut(duration: 0.3)) {
            headerOpacity = 1.0
        }
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.15)) {
            statsVisible = true
            emptyStateScale = 1.0
        }
        
        // Start attention pulse if needed
        if stats.needsAttention > 0 {
            startAttentionPulse()
        }
    }
    
    private func startAttentionPulse() {
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            attentionPulse = true
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 40))
                .foregroundStyle(.gray.opacity(0.5))
                .symbolEffect(.bounce, options: .speed(0.5), value: emptyStateScale == 1.0)
            
            Text("No Receipts Yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button {
             
                HapticService.play(.medium)
                
                showingReceiptScanner = true
            } label: {
                Label("Scan First Receipt", systemImage: "camera.fill")
                    .font(.subheadline)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppConstants.primaryColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .scaleEffect(emptyStateScale)
        .opacity(statsVisible ? 1 : 0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No receipts. Tap to scan your first receipt.")
    }
    
    // MARK: - Stats View
    
    private var statsView: some View {
        VStack(spacing: 12) {
            // Main Stats Row
            HStack(spacing: 16) {
                AnimatedStatPill(
                    value: stats.total,
                    label: "Total",
                    color: .blue,
                    delay: 0,
                    isVisible: statsVisible
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(stats.total) total receipts")
                
                AnimatedStatPill(
                    value: stats.matched,
                    label: "Matched",
                    color: .green,
                    delay: 0.1,
                    isVisible: statsVisible
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(stats.matched) matched receipts")
                
                AnimatedStatPill(
                    value: stats.unmatched,
                    label: "Unmatched",
                    color: .orange,
                    delay: 0.2,
                    isVisible: statsVisible
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(stats.unmatched) unmatched receipts")
            }
            
            Divider()
            
            // Tax Deductible Amount
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tax Deductible")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(stats.totalDeductible, format: .currency(code: currencyCode))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                        .contentTransition(.numericText())
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(taxDeductibleAccessibilityLabel(amount: stats.totalDeductible))
                
                Spacer()
                
                if stats.needsAttention > 0 {
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                                .scaleEffect(attentionPulse ? 1.1 : 1.0)
                            Text("\(stats.needsAttention)")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        
                        Text("Need Attention")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(stats.needsAttention) receipts need attention")
                    .onTapGesture {
                     
                        HapticService.play(.medium)
                        showingReceiptList = true
                    }
                }
            }
            .opacity(statsVisible ? 1 : 0)
            .offset(y: statsVisible ? 0 : 10)
            .animation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.25), value: statsVisible)
            
            // View All Button
            Button {
            
                HapticService.play(.medium)
                
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    viewAllPressed = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        viewAllPressed = false
                    }
                }
                
                showingReceiptList = true
            } label: {
                HStack {
                    Text("View All Receipts")
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.caption)
                }
                .foregroundStyle(AppConstants.primaryColor)
                .scaleEffect(viewAllPressed ? 0.98 : 1.0)
            }
            .accessibilityLabel("View all \(stats.total) receipts")
            .opacity(statsVisible ? 1 : 0)
            .animation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.35), value: statsVisible)
        }
    }
}

// MARK: - Animated Stat Pill

private struct AnimatedStatPill: View {
    let value: Int
    let label: String
    let color: Color
    let delay: Double
    let isVisible: Bool
    
    @State private var displayedValue: Int = 0
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(displayedValue)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
                .contentTransition(.numericText())
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
        .scaleEffect(isVisible ? (isPressed ? 0.95 : 1.0) : 0.8)
        .opacity(isVisible ? 1 : 0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(delay), value: isVisible)
        .onAppear {
            if isVisible {
                animateCounter()
            }
        }
        .onChange(of: isVisible) { _, newValue in
            if newValue {
                animateCounter()
            }
        }
        .onTapGesture {
        
            HapticService.play(.medium)
            
            withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                    isPressed = false
                }
            }
        }
    }
    
    private func animateCounter() {
        // Counter animation
        displayedValue = 0
        
        let animationDuration = 0.5
        let steps = min(value, 20)
        
        guard steps > 0 else {
            displayedValue = value
            return
        }
        
        let stepDuration = animationDuration / Double(steps)
        
        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + (stepDuration * Double(i))) {
                withAnimation(.easeOut(duration: 0.1)) {
                    displayedValue = Int(Double(value) * Double(i) / Double(steps))
                }
            }
        }
        
        // Ensure final value is exact
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + animationDuration + 0.05) {
            displayedValue = value
        }
    }
}

// MARK: - Stat Pill (Original for compatibility)

struct StatPill: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Receipt Stats

struct ReceiptStats {
    let total: Int
    let matched: Int
    let unmatched: Int
    let needsAttention: Int
    let totalDeductible: Double
}

// MARK: - Receipt List View

struct ReceiptListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ReceiptData.date, order: .reverse) private var receipts: [ReceiptData]
    
    @State private var filterMode: FilterMode = .all
    @State private var errorMessage: String?
    @State private var showingError = false
    
    private var filteredReceipts: [ReceiptData] {
        switch filterMode {
        case .all:
            return receipts
        case .matched:
            return receipts.filter { $0.matchStatus == .automaticMatch || $0.matchStatus == .manualMatch }
        case .unmatched:
            return receipts.filter { $0.matchStatus == .unmatched }
        case .needsAttention:
            return receipts.filter { $0.needsAttention }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Filter Picker with animation
                Picker("Filter", selection: $filterMode) {
                    ForEach(FilterMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .onChange(of: filterMode) { _, _ in
                    let generator = UISelectionFeedbackGenerator()
                    generator.selectionChanged()
                }
                
                // Receipts
                ForEach(filteredReceipts) { receipt in
                    ReceiptListRow(receipt: receipt)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
                .onDelete(perform: deleteReceipts)
            }
            .animation(.easeInOut(duration: 0.2), value: filterMode)
            .navigationTitle("Receipts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
  
                        HapticService.play(.medium)
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
    
    private func deleteReceipts(at offsets: IndexSet) {
    
        HapticService.play(.medium)
        
        let receiptsToDelete = offsets.map { filteredReceipts[$0] }
        
        receiptsToDelete.forEach { receipt in
            modelContext.delete(receipt)
        }
        
        do {
            try modelContext.save()
            
            let successGenerator = UINotificationFeedbackGenerator()
            successGenerator.notificationOccurred(.success)
            
            #if DEBUG
            print("✅ Deleted \(receiptsToDelete.count) receipt(s)")
            #endif
            
        } catch {
            errorMessage = "Failed to delete receipt: \(error.localizedDescription)"
            showingError = true
            
            let errorGenerator = UINotificationFeedbackGenerator()
            errorGenerator.notificationOccurred(.error)
            
            #if DEBUG
            print("❌ Delete error: \(error)")
            #endif
        }
    }
    
    enum FilterMode: String, CaseIterable {
        case all = "All"
        case matched = "Matched"
        case unmatched = "Unmatched"
        case needsAttention = "Needs Attention"
    }
}

// MARK: - Receipt List Row

struct ReceiptListRow: View {
    let receipt: ReceiptData
    
    @State private var isPressed = false
    
    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Status Indicator
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)
            
            // Receipt Info
            VStack(alignment: .leading, spacing: 4) {
                Text(receipt.merchantName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    Text(receipt.date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if let category = receipt.suggestedCategoryName {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(category)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Amount
            VStack(alignment: .trailing, spacing: 2) {
                Text(receipt.totalAmount, format: .currency(code: currencyCode))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                if receipt.needsAttention {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .accessibilityLabel("Needs attention")
                }
            }
        }
        .padding(.vertical, 4)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .onTapGesture {
 
            HapticService.play(.medium)
            
            withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                    isPressed = false
                }
            }
        }
    }
    
    private var statusColor: Color {
        switch receipt.matchStatus {
        case .automaticMatch, .manualMatch:
            return .green
        case .unmatched:
            return .orange
        case .noBankTransaction:
            return .blue
        case .duplicateWarning:
            return .red
        }
    }
    
    private var statusText: String {
        switch receipt.matchStatus {
        case .automaticMatch:
            return "automatically matched"
        case .manualMatch:
            return "manually matched"
        case .unmatched:
            return "unmatched"
        case .noBankTransaction:
            return "cash purchase"
        case .duplicateWarning:
            return "duplicate warning"
        }
    }
    
    private var accessibilityDescription: String {
        let amountFormatter = NumberFormatter()
        amountFormatter.numberStyle = .currency
        amountFormatter.currencyCode = currencyCode
        let formattedAmount = amountFormatter.string(from: NSNumber(value: receipt.totalAmount)) ?? "\(receipt.totalAmount)"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        let formattedDate = dateFormatter.string(from: receipt.date)
        
        var description = "\(receipt.merchantName), \(formattedAmount), \(formattedDate)"
        
        if let category = receipt.suggestedCategoryName {
            description += ", \(category)"
        }
        
        description += ", \(statusText)"
        
        if receipt.needsAttention {
            description += ", needs attention"
        }
        
        return description
    }
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
        
        let receipt1 = ReceiptData(
            merchantName: "Starbucks",
            totalAmount: 12.45,
            date: Date()
        )
        receipt1.suggestedCategoryName = "Meals & Entertainment"
        receipt1.matchStatus = .automaticMatch
        receipt1.isTaxDeductible = true
        
        let receipt2 = ReceiptData(
            merchantName: "Staples",
            totalAmount: 87.99,
            date: Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        )
        receipt2.matchStatus = .unmatched
        receipt2.suggestedCategoryName = "Office Supplies"
        receipt2.isTaxDeductible = true
        
        let receipt3 = ReceiptData(
            merchantName: "Target",
            totalAmount: 45.67,
            date: Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        )
        receipt3.matchStatus = .unmatched
        receipt3.deductionFlagged = false
        receipt3.suggestedCategoryName = "Supplies"
        
        context.insert(receipt1)
        context.insert(receipt2)
        context.insert(receipt3)
    }()
    
    return ReceiptManagementCard()
        .modelContainer(container)
        .padding()
}

#Preview("Empty State") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: ReceiptData.self,
        configurations: config
    )
    
    return ReceiptManagementCard()
        .modelContainer(container)
        .padding()
}
