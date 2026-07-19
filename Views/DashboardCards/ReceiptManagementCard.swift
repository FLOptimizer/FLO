//  ReceiptManagementCard.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 4.2 - ReceiptListView reusable as a pushed destination (More tab)
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Dashboard card showing receipt scanning status and actionable insights
//
//  CHANGES v4.2:
//  ✅ ADDED: ReceiptListView(embedInOwnStack:showScanButton:) so it can be pushed
//           onto an existing NavigationStack (e.g. the More tab → Receipts) instead
//           of only presented as a sheet. Pushed mode drops the inner NavigationStack
//           and "Done" button (system back button handles it) so the nav bar isn't doubled.
//  ✅ ADDED: Optional nav-bar scan button + empty-state "Scan a Receipt" CTA that
//           present SmartReceiptScanningView as a sheet, reloading the list on dismiss.
//  ✅ UNCHANGED: Existing sheet usage (dashboard "View All") keeps its own stack + Done.
//
//  CHANGES v4.0:
//  ✅ ADDED: Pending matches badge with tap to open matching queue
//  ✅ ADDED: Integration with ReceiptMatchingService
//  ✅ MIGRATED: All haptics to centralized HapticService
//  ✅ UPDATED: Animations to use FLOAnimation presets
//  ✅ IMPROVED: Stats view with match badge indicator
//
//  PREVIOUS (v3.0):
//  - Animated stat pills with staggered entrance
//  - Haptic feedback on scan button and view all actions
//  - Pulsing attention indicator for receipts needing review
//  - Progress counter animations for stats
//  - Card press states with scale effects
//

import SwiftUI
import FLODesignSystem
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct ReceiptManagementCard: View {
    @Environment(\.modelContext) private var modelContext
    @State private var receipts: [ReceiptData] = []
    @State private var transactions: [Transaction] = []
    
    @StateObject private var matchingService = ReceiptMatchingService.shared
    
    @State private var showingReceiptScanner = false
    @State private var showingReceiptList = false
    @State private var showingMatchingQueue = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    // Animation States
    @State private var headerOpacity: Double = 0
    @State private var statsVisible = false
    @State private var emptyStateScale: CGFloat = 0.8
    @State private var scanButtonPressed = false
    @State private var viewAllPressed = false
    @State private var attentionPulse = false
    @State private var badgeBounce = false
    
    // Get current locale currency code
    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }
    
    // Helper to format currency for accessibility labels
    private func taxDeductibleAccessibilityLabel(amount: Double) -> String {
        let formattedAmount = NumberFormatter.appCurrency.string(from: NSNumber(value: amount)) ?? "\(amount)"
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
                    .foregroundStyle(Color.brandPrimary)
                    .symbolEffect(.bounce, options: .speed(0.5), value: headerOpacity > 0)
                    .accessibilityHidden(true)
                
                Text("Receipt Management")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                
                Spacer()
                
                // Pending Matches Badge (NEW)
                if matchingService.pendingMatchCount > 0 {
                    Button {
                        HapticService.play(.medium)
                        showingMatchingQueue = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "link.badge.plus")
                                .font(.caption)
                                .accessibilityHidden(true)
                            Text("\(matchingService.pendingMatchCount) to match")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.brandPrimary.opacity(0.15))
                        .foregroundStyle(Color.brandPrimary)
                        .cornerRadius(12)
                        .scaleEffect(badgeBounce ? 1.05 : 1.0)
                    }
                    .accessibilityLabel("\(matchingService.pendingMatchCount) receipts ready to match")
                }
                
                Button {
                    HapticService.play(.medium)
                    
                    withAnimation(FLOAnimation.quick) {
                        scanButtonPressed = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(FLOAnimation.quick) {
                            scanButtonPressed = false
                        }
                    }
                    
                    showingReceiptScanner = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.brandPrimary)
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
        .background(Color.floSecondarySystemBackground)
        .cornerRadius(12)
        .task {
            loadData()
            animateEntrance()
            // Scan for pending matches
            matchingService.scanForMatches(receipts: receipts, transactions: transactions)
        }
        .onDisappear {
            receipts = []
            transactions = []
        }
        .onChange(of: receipts.count) { _, _ in
            // Rescan when receipts change
            matchingService.scanForMatches(receipts: receipts, transactions: transactions)
        }
        .onChange(of: transactions.count) { _, _ in
            // Rescan when transactions change (including Plaid imports!)
            matchingService.scanForMatches(receipts: receipts, transactions: transactions)
        }
        .sheet(isPresented: $showingReceiptScanner) {
            SmartReceiptScanningView()
        }
        .sheet(isPresented: $showingReceiptList) {
            ReceiptListView()
        }
        .sheet(isPresented: $showingMatchingQueue) {
            ReceiptMatchingQueueView()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Data Loading

    private func loadData() {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        let endOfYear = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1))!

        let receiptDescriptor = FetchDescriptor<ReceiptData>(
            predicate: #Predicate<ReceiptData> { $0.date >= startOfYear && $0.date < endOfYear }
        )
        let transactionDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.date >= startOfYear && $0.date < endOfYear }
        )

        do {
            receipts = try modelContext.fetch(receiptDescriptor)
            transactions = try modelContext.fetch(transactionDescriptor)
        } catch {
            #if DEBUG
            print("ReceiptManagementCard loadData error: \(error)")
            #endif
        }
    }

    // MARK: - Animations

    private func animateEntrance() {
        withAnimation(FLOAnimation.standard) {
            headerOpacity = 1.0
        }
        
        withAnimation(FLOAnimation.bouncy.delay(0.15)) {
            statsVisible = true
            emptyStateScale = 1.0
        }
        
        // Start attention pulse if needed
        if stats.needsAttention > 0 {
            startAttentionPulse()
        }
        
        // Badge bounce for pending matches
        if matchingService.pendingMatchCount > 0 {
            startBadgeBounce()
        }
    }
    
    private func startAttentionPulse() {
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            attentionPulse = true
        }
    }
    
    private func startBadgeBounce() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(FLOAnimation.bouncy) {
                badgeBounce = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(FLOAnimation.bouncy) {
                    badgeBounce = false
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.viewfinder")
                .font(.largeTitle)
                .foregroundStyle(.gray.opacity(0.5))
                .symbolEffect(.bounce, options: .speed(0.5), value: emptyStateScale == 1.0)
                .accessibilityHidden(true)
            
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
            .tint(Color.brandPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .scaleEffect(emptyStateScale)
        .opacity(statsVisible ? 1 : 0.001)
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
                
                // Unmatched with badge indicator
                ZStack(alignment: .topTrailing) {
                    AnimatedStatPill(
                        value: stats.unmatched,
                        label: "Unmatched",
                        color: .orange,
                        delay: 0.2,
                        isVisible: statsVisible
                    )
                    
                    // Show indicator if matches available
                    if matchingService.pendingMatchCount > 0 {
                        Circle()
                            .fill(Color.brandPrimary)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(stats.unmatched) unmatched receipts")
                .onTapGesture {
                    if matchingService.pendingMatchCount > 0 {
                        HapticService.play(.medium)
                        showingMatchingQueue = true
                    }
                }
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
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                        .contentTransition(.numericText())
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(taxDeductibleAccessibilityLabel(amount: stats.totalDeductible))
                
                Spacer()
                
                Button {
                    HapticService.play(.light)
                    
                    withAnimation(FLOAnimation.quick) {
                        viewAllPressed = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(FLOAnimation.quick) {
                            viewAllPressed = false
                        }
                    }
                    
                    showingReceiptList = true
                } label: {
                    HStack(spacing: 4) {
                        Text("View All")
                            .font(.subheadline)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(Color.brandPrimary)
                    .scaleEffect(viewAllPressed ? 0.95 : 1.0)
                }
                .accessibilityLabel("View all receipts")
            }
            
            // Needs Attention Warning
            if stats.needsAttention > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .opacity(attentionPulse ? 1.0 : 0.6)
                        .accessibilityHidden(true)
                    
                    Text("\(stats.needsAttention) receipt\(stats.needsAttention == 1 ? "" : "s") need\(stats.needsAttention == 1 ? "s" : "") attention")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    
                    Spacer()
                }
                .padding(.top, 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(stats.needsAttention) receipts need attention")
            }
        }
        .opacity(statsVisible ? 1 : 0.001)
        .animation(FLOAnimation.standard.delay(0.1), value: statsVisible)
    }
}

// MARK: - Receipt Stats Model

struct ReceiptStats {
    let total: Int
    let matched: Int
    let unmatched: Int
    let needsAttention: Int
    let totalDeductible: Double
}

// MARK: - Animated Stat Pill

struct AnimatedStatPill: View {
    let value: Int
    let label: String
    let color: Color
    let delay: Double
    let isVisible: Bool
    
    @State private var displayValue: Int = 0
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(displayValue)")
                .font(.title3)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
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
        .scaleEffect(isVisible ? 1 : 0.8)
        .opacity(isVisible ? 1 : 0.001)
        .animation(FLOAnimation.bouncy.delay(delay), value: isVisible)
        .onChange(of: isVisible) { _, newValue in
            if newValue {
                animateValue()
            }
        }
        .onChange(of: value) { _, newValue in
            withAnimation(FLOAnimation.standard) {
                displayValue = newValue
            }
        }
    }
    
    private func animateValue() {
        // Animate from 0 to actual value
        let duration = 0.5
        let steps = 10
        let stepDuration = duration / Double(steps)
        
        for step in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + (stepDuration * Double(step))) {
                withAnimation(.linear(duration: stepDuration)) {
                    displayValue = Int(Double(value) * Double(step) / Double(steps))
                }
            }
        }
    }
}

// MARK: - Receipt List View (Internal)

struct ReceiptListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// When true (default — sheet presentation) the view supplies its own
    /// NavigationStack and a "Done" button. When false (pushed onto an existing
    /// stack, e.g. the More tab) it renders bare and relies on the system back
    /// button so the nav bar isn't doubled.
    var embedInOwnStack: Bool = true
    /// When true, shows a scan button in the nav bar that opens the receipt
    /// scanner as a sheet, plus a "Scan a Receipt" CTA in the empty state.
    var showScanButton: Bool = false

    @State private var receipts: [ReceiptData] = []
    @State private var filterMode: FilterMode = .all
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showingScanner = false
    @State private var viewAppeared = false
    
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
        if embedInOwnStack {
            NavigationStack {
                listContent
            }
        } else {
            listContent
        }
    }

    private var listContent: some View {
        Group {
            if filteredReceipts.isEmpty {
                ContentUnavailableView {
                    Label("No Receipts", systemImage: "doc.text")
                } description: {
                    Text(filterMode == .all
                         ? "Scan a receipt to get started."
                         : "No receipts match the current filter.")
                } actions: {
                    if showScanButton {
                        Button {
                            HapticService.play(.light)
                            showingScanner = true
                        } label: {
                            Label("Scan a Receipt", systemImage: "doc.text.viewfinder")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                List {
                    ForEach(Array(filteredReceipts.enumerated()), id: \.element.id) { index, receipt in
                        ReceiptListRow(receipt: receipt)
                            .opacity(viewAppeared ? 1 : 0.001)
                            .offset(x: viewAppeared ? 0 : 20)
                            .animation(
                                FLOAnimation.standard.delay(Double(min(index, 10)) * 0.03),
                                value: viewAppeared
                            )
                    }
                    .onDelete(perform: deleteReceipts)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Receipts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if embedInOwnStack {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        HapticService.play(.light)
                        dismiss()
                    }
                }
            }

            if showScanButton {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticService.play(.light)
                        showingScanner = true
                    } label: {
                        Image(systemName: "doc.text.viewfinder")
                    }
                    .accessibilityLabel("Scan Receipt")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(FilterMode.allCases, id: \.self) { mode in
                        Button {
                            HapticService.play(.selection)
                            filterMode = mode
                        } label: {
                            HStack {
                                Text(mode.rawValue)
                                if filterMode == mode {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(isPresented: $showingScanner, onDismiss: { loadData() }) {
            SmartReceiptScanningView()
        }
        .task {
            loadData()
        }
        .onDisappear {
            receipts = []
        }
        .onAppear {
            withAnimation(FLOAnimation.standard) {
                viewAppeared = true
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

    // MARK: - Data Loading

    private func loadData() {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        let endOfYear = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1))!

        let descriptor = FetchDescriptor<ReceiptData>(
            predicate: #Predicate<ReceiptData> { $0.date >= startOfYear && $0.date < endOfYear },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        do {
            receipts = try modelContext.fetch(descriptor)
        } catch {
            #if DEBUG
            print("ReceiptListView loadData error: \(error)")
            #endif
        }
    }

    private func deleteReceipts(at offsets: IndexSet) {
        HapticService.play(.heavy)
        
        let receiptsToDelete = offsets.map { filteredReceipts[$0] }
        
        receiptsToDelete.forEach { receipt in
            modelContext.delete(receipt)
        }
        
        do {
            try modelContext.save()
            HapticService.play(.success)
            
            #if DEBUG
            print("✅ Deleted \(receiptsToDelete.count) receipt(s)")
            #endif
            
        } catch {
            errorMessage = "Failed to delete receipt: \(error.localizedDescription)"
            showingError = true
            HapticService.play(.error)
            
            #if DEBUG
            print("✓ Delete error: \(error)")
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

// MARK: - Receipt Thumbnail Cache

/// In-memory NSCache for decoded receipt thumbnails. Evicted automatically under memory pressure.
@MainActor
final class ReceiptThumbnailCache {
    static let shared = ReceiptThumbnailCache()

    #if canImport(UIKit)
    private let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 200
        c.totalCostLimit = 50 * 1024 * 1024  // 50 MB
        return c
    }()

    func image(for filename: String) -> UIImage? {
        cache.object(forKey: filename as NSString)
    }

    func store(_ image: UIImage, for filename: String) {
        let cost = image.jpegData(compressionQuality: 1)?.count ?? 0
        cache.setObject(image, forKey: filename as NSString, cost: cost)
    }
    #endif

    private init() {}
}

// MARK: - Receipt Thumbnail View

/// Asynchronously loads and displays a receipt thumbnail. Shows a placeholder while loading.
/// Uses ReceiptThumbnailCache for in-memory caching; falls back to generating from the
/// full image if the thumbnail file is absent.
struct ReceiptThumbnailView: View {
    let filename: String?
    let size: CGFloat

    #if canImport(UIKit)
    @State private var thumbnail: UIImage?
    #endif

    var body: some View {
        Group {
            #if canImport(UIKit)
            if let image = thumbnail {
                Image(platformImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "doc.text.image")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(.secondary)
            }
            #else
            Image(systemName: "doc.text.image")
                .font(.system(size: size * 0.4))
                .foregroundStyle(.secondary)
            #endif
        }
        .frame(width: size, height: size)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        #if canImport(UIKit)
        .task(id: filename) {
            await loadThumbnail()
        }
        #endif
    }

    #if canImport(UIKit)
    private func loadThumbnail() async {
        guard let filename, !filename.isEmpty else { return }

        // Check in-memory cache first
        if let cached = await ReceiptThumbnailCache.shared.image(for: filename) {
            thumbnail = cached
            return
        }

        // Load from disk (PhotoStorageManager generates if missing)
        guard let image = try? await PhotoStorageManager.shared.loadThumbnail(filename: filename) else { return }
        await ReceiptThumbnailCache.shared.store(image, for: filename)
        thumbnail = image
    }
    #endif
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

            // Thumbnail (file-backed receipts only)
            if receipt.imageURL != nil {
                ReceiptThumbnailView(filename: receipt.imageURL, size: 44)
                    .accessibilityHidden(true)
            }

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
    
    private var accessibilityDescription: String {
        let formattedAmount = NumberFormatter.appCurrency.string(from: NSNumber(value: receipt.totalAmount)) ?? "\(receipt.totalAmount)"

        let formattedDate = DateFormatter.mediumDate.string(from: receipt.date)
        
        var description = "\(receipt.merchantName), \(formattedAmount), \(formattedDate)"
        
        if let category = receipt.suggestedCategoryName {
            description += ", \(category)"
        }
        
        description += ", \(receipt.matchStatus.displayName)"
        
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
        for: ReceiptData.self, Transaction.self,
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
        
        // Add a transaction to potentially match
        let transaction = Transaction(
            amount: 87.99,
            date: Calendar.current.date(byAdding: .day, value: -3, to: Date())!,
            note: "Office supplies",
            isIncome: false,
            merchantName: "Staples Office"
        )
        
        context.insert(receipt1)
        context.insert(receipt2)
        context.insert(receipt3)
        context.insert(transaction)
    }()
    
    return ReceiptManagementCard()
        .modelContainer(container)
        .padding()
}

#Preview("Empty State") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: ReceiptData.self, Transaction.self,
        configurations: config
    )
    
    return ReceiptManagementCard()
        .modelContainer(container)
        .padding()
}
