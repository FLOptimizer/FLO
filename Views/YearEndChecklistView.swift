//
//  YearEndChecklistView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - Enhanced haptics and micro-animations
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES FROM v1.0:
//  ✅ Haptic feedback on item tap, mark complete
//  ✅ Section entrance stagger animations
//  ✅ Progress ring animation
//  ✅ Checklist item completion animation
//  ✅ Feature item icon bounce
//
//  Activated in November-December to help users maximize tax deductions
//  before year-end with personalized strategies and deadline tracking.
//

import SwiftUI
import SwiftData

struct YearEndChecklistView: View {
    @Query private var transactions: [Transaction]
    @Query private var mileageTrips: [MileageTrip]
    @Query private var receipts: [ReceiptData]
    @Query private var taxSettings: [TaxSettings]
    @Query private var businessProfiles: [BusinessProfile]
    
    @State private var checklist: TaxYearEndChecklist?
    @State private var isLoading = true
    @State private var selectedItem: TaxChecklistItem?
    @State private var viewAppeared = false
    
    // Haptic Generators
                
    private var settings: TaxSettings {
        taxSettings.first ?? TaxSettings()
    }
    
    private var businessProfile: BusinessProfile? {
        businessProfiles.first
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else if let checklist = checklist, checklist.isActive {
                    checklistContent(checklist)
                } else {
                    inactiveView
                }
            }
            .navigationTitle("Year-End Tax Planning")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                                withAnimation(FLOAnimation.standard) {
                    viewAppeared = true
                }
                Task {
                    await generateChecklist()
                }
            }
        }
    }
    
    // MARK: - Haptic Preparation
    
        
    // MARK: - Loading State
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.brandPrimary)
            
            Text("Generating your personalized checklist...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .opacity(viewAppeared ? 1 : 0)
        .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
    }
    
    // MARK: - Inactive State (Not November-December)
    
    private var inactiveView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 80))
                    .foregroundStyle(.secondary)
                    .symbolEffect(.pulse, options: .repeating.speed(0.5))
                    .opacity(viewAppeared ? 1 : 0)
                    .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
                
                Text("Year-End Planning Inactive")
                    .font(.title2.bold())
                    .opacity(viewAppeared ? 1 : 0)
                    .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)
                
                Text("This feature activates in November and December to help you maximize tax deductions before year-end.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(viewAppeared ? 1 : 0)
                    .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("What to expect:")
                        .font(.headline)
                    
                    FeatureItem(
                        icon: "checkmark.circle.fill",
                        text: "Personalized action items based on your income"
                    )
                    FeatureItem(
                        icon: "dollarsign.circle.fill",
                        text: "Estimated tax savings for each strategy"
                    )
                    FeatureItem(
                        icon: "calendar.badge.exclamationmark",
                        text: "Deadline tracking for time-sensitive deductions"
                    )
                    FeatureItem(
                        icon: "lightbulb.fill",
                        text: "Advanced strategies like prepaying expenses"
                    )
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                .opacity(viewAppeared ? 1 : 0)
                .offset(y: viewAppeared ? 0 : 15)
                .animation(FLOAnimation.standard.delay(0.25), value: viewAppeared)
            }
            .padding(.vertical, 40)
        }
    }
    
    struct FeatureItem: View {
        let icon: String
        let text: String
        @State private var iconBounce = false
        
        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.brandPrimary)
                    .frame(width: 24)
                    .symbolEffect(.bounce, value: iconBounce)
                
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    iconBounce = true
                }
            }
        }
    }
    
    // MARK: - Active Checklist Content
    
    private func checklistContent(_ checklist: TaxYearEndChecklist) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                progressHeader(checklist)
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(y: viewAppeared ? 0 : 15)
                    .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)
                
                savingsSummary(checklist)
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(y: viewAppeared ? 0 : 15)
                    .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
                
                checklistSections(checklist)
                
                disclaimerView
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(y: viewAppeared ? 0 : 15)
                    .animation(FLOAnimation.standard.delay(0.4), value: viewAppeared)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Progress Header
    
    private func progressHeader(_ checklist: TaxYearEndChecklist) -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Year-End Planning \(checklist.year)")
                        .font(.title2.bold())
                    
                    Text("\(Int(checklist.completionPercentage * 100))% Complete")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: viewAppeared ? checklist.completionPercentage : 0)
                        .stroke(Color.brandPrimary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3), value: viewAppeared)
                    
                    Text("\(Int(checklist.completionPercentage * 100))%")
                        .font(.caption.bold())
                        .foregroundColor(.brandPrimary)
                        .contentTransition(.numericText())
                }
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.brandPrimary)
                        .frame(width: viewAppeared ? geometry.size.width * checklist.completionPercentage : 0, height: 8)
                        .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3), value: viewAppeared)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Savings Summary
    
    private func savingsSummary(_ checklist: TaxYearEndChecklist) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.title)
                    .foregroundColor(.green)
                    .symbolEffect(.bounce, value: viewAppeared)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Potential Tax Savings")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text("$\(String(format: "%.0f", checklist.totalPotentialSavings))")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.green)
                        .contentTransition(.numericText())
                }
                
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Completed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(checklist.items.filter { $0.isCompleted }.count) items")
                        .font(.subheadline.bold())
                        .contentTransition(.numericText())
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(checklist.items.filter { !$0.isCompleted }.count) items")
                        .font(.subheadline.bold())
                        .contentTransition(.numericText())
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.green.opacity(0.1), Color.brandPrimary.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
    }
    
    // MARK: - Checklist Sections
    
    @ViewBuilder
    private func checklistSections(_ checklist: TaxYearEndChecklist) -> some View {
        if !highPriorityItems(checklist).isEmpty {
            checklistSection(
                title: "High Priority",
                icon: "exclamationmark.triangle.fill",
                color: .red,
                items: highPriorityItems(checklist)
            )
            .opacity(viewAppeared ? 1 : 0)
            .offset(y: viewAppeared ? 0 : 15)
            .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)
        }
        
        if !mediumPriorityItems(checklist).isEmpty {
            checklistSection(
                title: "Medium Priority",
                icon: "flag.fill",
                color: .orange,
                items: mediumPriorityItems(checklist)
            )
            .opacity(viewAppeared ? 1 : 0)
            .offset(y: viewAppeared ? 0 : 15)
            .animation(FLOAnimation.standard.delay(0.25), value: viewAppeared)
        }
        
        if !lowPriorityItems(checklist).isEmpty {
            checklistSection(
                title: "Low Priority",
                icon: "flag",
                color: .gray,
                items: lowPriorityItems(checklist)
            )
            .opacity(viewAppeared ? 1 : 0)
            .offset(y: viewAppeared ? 0 : 15)
            .animation(FLOAnimation.standard.delay(0.35), value: viewAppeared)
        }
    }
    
    private func checklistSection(title: String, icon: String, color: Color, items: [TaxChecklistItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
            }
            
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                ChecklistItemRow(item: item) {
                    HapticService.play(.light)
                    selectedItem = item
                }
                .opacity(viewAppeared ? 1 : 0)
                .offset(x: viewAppeared ? 0 : 20)
                .animation(
                    FLOAnimation.standard
                    .delay(0.2 + Double(index) * 0.05),
                    value: viewAppeared
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .sheet(item: $selectedItem) { item in
            ChecklistItemDetailView(item: item)
        }
    }
    
    struct ChecklistItemRow: View {
        let item: TaxChecklistItem
        let onTap: () -> Void
        @State private var isPressed = false
        
        var body: some View {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(item.isCompleted ? .green : .secondary)
                        .font(.title3)
                        .contentTransition(.symbolEffect(.replace))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.subheadline.bold())
                            .foregroundStyle(item.isCompleted ? .secondary : .primary)
                            .strikethrough(item.isCompleted)
                        
                        if item.potentialSavings > 0 {
                            Text("Potential: $\(String(format: "%.0f", item.potentialSavings))")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(item.deadline, style: .relative)
                            .font(.caption)
                            .foregroundStyle(
                                Calendar.current.dateComponents([.day], from: Date(), to: item.deadline).day ?? 0 <= 7 ? .red : .secondary
                            )
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(10)
                .scaleEffect(isPressed ? 0.98 : 1.0)
            }
            .buttonStyle(.plain)
            .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isPressed = pressing
                }
            }, perform: {})
        }
    }
    
    // MARK: - Disclaimer
    
    private var disclaimerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.orange)
                Text("Important Disclaimer")
                    .font(.caption.bold())
            }
            
            Text("This checklist provides general tax guidance. Your specific situation may vary. Always consult a qualified tax professional for personalized advice before making tax-related decisions.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Functions
    
    private func highPriorityItems(_ checklist: TaxYearEndChecklist) -> [TaxChecklistItem] {
        checklist.items.filter { $0.priority == .high }
    }
    
    private func mediumPriorityItems(_ checklist: TaxYearEndChecklist) -> [TaxChecklistItem] {
        checklist.items.filter { $0.priority == .medium }
    }
    
    private func lowPriorityItems(_ checklist: TaxYearEndChecklist) -> [TaxChecklistItem] {
        checklist.items.filter { $0.priority == .low }
    }
    
    // MARK: - Generate Checklist
    
    @MainActor
    private func generateChecklist() async {
        isLoading = true
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        guard transactions.first?.modelContext != nil else {
            isLoading = false
            return
        }
        
        checklist = TaxOptimizationEngine.shared.generateYearEndChecklist(
            transactions: transactions,
            mileageTrips: mileageTrips,
            receipts: receipts,
            taxSettings: settings,
            businessProfile: businessProfile
        )
        
        isLoading = false
        
        #if DEBUG
        if let checklist = checklist, checklist.isActive {
            print("📋 Year-End Checklist: \(checklist.items.count) items")
            print("   Total savings: $\(String(format: "%.0f", checklist.totalPotentialSavings))")
        } else {
            print("📋 Year-End Checklist: Inactive (not November-December)")
        }
        #endif
    }
}

// MARK: - Checklist Item Detail Sheet

struct ChecklistItemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State var item: TaxChecklistItem
    @State private var viewAppeared = false
    
    // Haptic Generators
                
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Priority badge
                    HStack {
                        Label {
                            Text(item.priority.displayName)
                                .font(.subheadline.bold())
                        } icon: {
                            Image(systemName: "flag.fill")
                        }
                        .foregroundColor(
                            item.priority == .high ? .red :
                            item.priority == .medium ? .orange : .gray
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            (item.priority == .high ? Color.red :
                             item.priority == .medium ? Color.orange : Color.gray)
                                .opacity(0.1)
                        )
                        .cornerRadius(8)
                        
                        Spacer()
                    }
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)
                    
                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What This Means")
                            .font(.headline)
                        
                        Text(item.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
                    
                    // Potential savings
                    if item.potentialSavings > 0 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Potential Tax Savings")
                                .font(.headline)
                            
                            Text("$\(String(format: "%.0f", item.potentialSavings))")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.green)
                                .contentTransition(.numericText())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color.green.opacity(0.1), Color.brandPrimary.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(12)
                        .opacity(viewAppeared ? 1 : 0)
                        .offset(y: viewAppeared ? 0 : 10)
                        .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)
                    }
                    
                    // Action steps
                    if !item.actionItems.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Action Steps")
                                .font(.headline)
                            
                            ForEach(Array(item.actionItems.enumerated()), id: \.offset) { index, action in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                        .frame(width: 24, height: 24)
                                        .background(Color.brandPrimary)
                                        .cornerRadius(12)
                                    
                                    Text(action)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .opacity(viewAppeared ? 1 : 0)
                        .offset(y: viewAppeared ? 0 : 10)
                        .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)
                    }
                    
                    // Deadline warning
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .foregroundColor(.orange)
                            Text("Deadline")
                                .font(.headline)
                        }
                        
                        Text(item.deadline, style: .date)
                            .font(.title3.bold())
                            .foregroundColor(.orange)
                        
                        Text(item.deadline, style: .relative)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.25), value: viewAppeared)
                    
                    // Mark complete button
                    Button {
                        HapticService.play(.medium)
                        withAnimation(FLOAnimation.quick) {
                            item.isCompleted.toggle()
                        }
                        if item.isCompleted {
                            HapticService.play(.success)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            dismiss()
                        }
                    } label: {
                        Label {
                            Text(item.isCompleted ? "Mark Incomplete" : "Mark Complete")
                                .font(.headline)
                        } icon: {
                            Image(systemName: item.isCompleted ? "xmark.circle.fill" : "checkmark.circle.fill")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(item.isCompleted ? Color.gray : Color.green)
                        .cornerRadius(12)
                    }
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.3), value: viewAppeared)
                }
                .padding()
            }
            .navigationTitle(item.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        HapticService.play(.light)
                        dismiss()
                    }
                }
            }
            .onAppear {

                withAnimation(FLOAnimation.standard) {
                    viewAppeared = true
                }
            }
        }
    }
}

// MARK: - Preview Provider

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Transaction.self, MileageTrip.self, ReceiptData.self,
        TaxSettings.self, BusinessProfile.self,
        configurations: config
    )
    
    return YearEndChecklistView()
        .modelContainer(container)
}
