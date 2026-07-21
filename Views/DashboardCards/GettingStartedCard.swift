//  GettingStartedCard.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.5 - Free-tier receipt task
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v3.5:
//  ✅ ADDED: "Scan your first receipt" to the Free tier list. Smart Scanner
//           moved to Free (SubscriptionTier v1.6) but the checklist was never
//           updated, so free users weren't guided to a feature they now have.
//           Tax profile icon moved to cyan to match Premium/Pro rows.
//
//  CHANGES v3.4.2:
//  ✅ FIXED (iPad §8): On first load with seeded data the card showed
//           "0 of 8 completed" until the user tapped Dashboard refresh. The
//           `.task` completion check could run BEFORE the async demo seed
//           finished, and nothing re-checked afterward. Now also re-runs
//           checkCompletionStatus() on `.demoDataSeeded` so the seeded state
//           resolves to "You're all set!" without a manual refresh. Mirrors
//           DashboardView v3.13 / DashboardSummaryPanel v1.1.
//
//  CHANGES v3.2:
//  - Fixed "X of Y completed" text contrast on gradient background
//  - Used .primary.opacity(0.65) + fontWeight(.medium) for WCAG AA compliance
//
//  CHANGES v3.1:
//  - Fixed "Setup progress" hit area too small error
//  - Progress bar now hidden from accessibility (parent header announces progress)
//
//  CHANGES v3.0:
//  ✅ Tier-specific task lists (Free: 4, Premium: 6, Pro: 8)
//  ✅ Completed tasks animate OUT (not strikethrough)
//  ✅ Card shrinks as tasks complete
//  ✅ Professional checkmark animation on completion
//  ✅ Graceful card exit when all tasks done
//  ✅ Tax Profile → navigates to Tax Settings in MoreView
//
//  CHANGES v2.0:
//  - Added 6 tasks, organized by category
//  - Smart detection of completed tasks
//

import SwiftUI
import FLODesignSystem
import SwiftData

/// Getting Started checklist card shown on Dashboard after onboarding
/// Guides users through essential setup tasks based on their subscription tier
struct GettingStartedCard: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @ObservedObject private var navigation = NavigationService.shared
    
    // Sheet presentations from DashboardView
    @Binding var showingAddTransaction: Bool
    @Binding var showingReceiptScanner: Bool
    
    // Internal navigation states
    @State private var showingBudgetList = false
    @State private var showingMileageSetup = false
    @State private var showingClientManagement = false
    @State private var showingInvoiceCreate = false
    @State private var showingAccountsView = false
    @State private var showingReportsView = false
    @State private var showingTaxSettings = false
    @State private var showingBusinessProfile = false
    
    // Persistence
    @AppStorage("hasDismissedGettingStarted") private var hasDismissed = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasTaxProfileSetup") private var hasTaxProfileSetup = false
    @AppStorage("hasBusinessProfileSetup") private var hasBusinessProfileSetup = false
    @AppStorage("hasMileageSetupCompleted") private var hasMileageSetupCompleted = false
    @AppStorage("hasExploredReports") private var hasExploredReports = false
    
    // Completion status (uses fetchCount for performance — no object deserialization)
    @State private var hasTransactions = false
    @State private var hasBudgets = false
    @State private var hasAccounts = false
    @State private var hasTaxSettings = false
    @State private var hasClients = false
    @State private var hasInvoices = false
    @State private var hasReceipts = false
    @State private var hasBusinessProfiles = false
    @State private var hasMileageTrips = false
    
    // UI State
    @State private var isExpanded = true
    @State private var viewAppeared = false
    @State private var showingAllComplete = false
    @State private var completedTaskIds: Set<String> = []
    
    // MARK: - Computed Properties
    
    private var currentTier: SubscriptionTier {
        subscriptionManager.currentTier
    }
    
    /// Tasks for current subscription tier
    private var tasksForTier: [FLOSetupTask] {
        switch currentTier {
        case .free:
            return freeTierTasks
        case .premium:
            return premiumTierTasks
        case .pro:
            return proTierTasks
        }
    }
    
    /// Only show incomplete tasks
    private var visibleTasks: [FLOSetupTask] {
        tasksForTier.filter { !$0.isCompleted && !completedTaskIds.contains($0.id) }
    }
    
    private var completedCount: Int {
        tasksForTier.filter { $0.isCompleted || completedTaskIds.contains($0.id) }.count
    }
    
    private var totalCount: Int {
        tasksForTier.count
    }
    
    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }
    
    private var allTasksCompleted: Bool {
        completedCount == totalCount
    }
    
    private var shouldShowCard: Bool {
        hasCompletedOnboarding && !hasDismissed && !allTasksCompleted && !showingAllComplete
    }
    
    // MARK: - Task Definitions
    
    // FREE TIER: 6 essential tasks
    private var freeTierTasks: [FLOSetupTask] {
        [
            FLOSetupTask(
                id: "account",
                title: "Create an account",
                subtitle: "Track your money in one place",
                icon: "banknote.fill",
                iconColor: .green,
                isCompleted: hasAccounts
            ),
            FLOSetupTask(
                id: "transaction",
                title: "Add your first transaction",
                subtitle: "Track income or expenses",
                icon: "plus.circle.fill",
                iconColor: .blue,
                isCompleted: hasTransactions
            ),
            FLOSetupTask(
                id: "receipt",
                title: "Scan your first receipt",
                subtitle: "Auto-extract expense details",
                icon: "camera.fill",
                iconColor: .orange,
                isCompleted: hasReceipts
            ),
            FLOSetupTask(
                id: "tax_profile",
                title: "Set up your tax profile",
                subtitle: "For accurate quarterly estimates",
                icon: "percent",
                iconColor: .cyan,
                isCompleted: hasTaxSettings || hasTaxProfileSetup
            ),
            FLOSetupTask(
                id: "budget",
                title: "Create your first budget",
                subtitle: "Stay on track with spending",
                icon: "chart.pie.fill",
                iconColor: .teal,
                isCompleted: hasBudgets
            ),
            FLOSetupTask(
                id: "reports",
                title: "Explore reports",
                subtitle: "See your financial insights",
                icon: "chart.bar.fill",
                iconColor: .purple,
                isCompleted: hasExploredReports
            )
        ]
    }
    
    // PREMIUM TIER: 7 tasks (essentials + premium features)
    private var premiumTierTasks: [FLOSetupTask] {
        [
            FLOSetupTask(
                id: "account",
                title: "Create an account",
                subtitle: "Track your money in one place",
                icon: "banknote.fill",
                iconColor: .green,
                isCompleted: hasAccounts
            ),
            FLOSetupTask(
                id: "transaction",
                title: "Add your first transaction",
                subtitle: "Track income or expenses",
                icon: "plus.circle.fill",
                iconColor: .blue,
                isCompleted: hasTransactions
            ),
            FLOSetupTask(
                id: "receipt",
                title: "Scan your first receipt",
                subtitle: "Auto-extract expense details",
                icon: "camera.fill",
                iconColor: .orange,
                isCompleted: hasReceipts
            ),
            FLOSetupTask(
                id: "tax_profile",
                title: "Set up your tax profile",
                subtitle: "For accurate quarterly estimates",
                icon: "percent",
                iconColor: .cyan,
                isCompleted: hasTaxSettings || hasTaxProfileSetup
            ),
            FLOSetupTask(
                id: "budget",
                title: "Create your first budget",
                subtitle: "Stay on track with spending",
                icon: "chart.pie.fill",
                iconColor: .teal,
                isCompleted: hasBudgets
            ),
            FLOSetupTask(
                id: "client",
                title: "Create a client profile",
                subtitle: "Prepare for invoicing",
                icon: "person.crop.circle.fill",
                iconColor: .indigo,
                isCompleted: hasClients
            ),
            FLOSetupTask(
                id: "mileage",
                title: "Set up mileage tracking",
                subtitle: "Maximize your deductions",
                icon: "car.fill",
                iconColor: .purple,
                isCompleted: hasMileageTrips || hasMileageSetupCompleted
            )
        ]
    }

    // PRO TIER: 8 tasks (all features)
    private var proTierTasks: [FLOSetupTask] {
        [
            FLOSetupTask(
                id: "bank_account",
                title: "Link a bank account",
                subtitle: "Auto-import your transactions",
                icon: "building.columns.fill",
                iconColor: .green,
                isCompleted: hasAccounts
            ),
            FLOSetupTask(
                id: "transaction",
                title: "Add your first transaction",
                subtitle: "Or let Plaid sync them automatically",
                icon: "plus.circle.fill",
                iconColor: .blue,
                isCompleted: hasTransactions
            ),
            FLOSetupTask(
                id: "receipt",
                title: "Scan your first receipt",
                subtitle: "Auto-extract expense details",
                icon: "camera.fill",
                iconColor: .orange,
                isCompleted: hasReceipts
            ),
            FLOSetupTask(
                id: "tax_profile",
                title: "Set up your tax profile",
                subtitle: "For accurate quarterly estimates",
                icon: "percent",
                iconColor: .cyan,
                isCompleted: hasTaxSettings || hasTaxProfileSetup
            ),
            FLOSetupTask(
                id: "business_profile",
                title: "Create business profile",
                subtitle: "Your info for professional invoices",
                icon: "building.2.fill",
                iconColor: .indigo,
                isCompleted: hasBusinessProfiles || hasBusinessProfileSetup
            ),
            FLOSetupTask(
                id: "budget",
                title: "Create your first budget",
                subtitle: "Stay on track with spending",
                icon: "chart.pie.fill",
                iconColor: .teal,
                isCompleted: hasBudgets
            ),
            FLOSetupTask(
                id: "invoice",
                title: "Create your first invoice",
                subtitle: "Get paid for your work",
                icon: "doc.text.fill",
                iconColor: .purple,
                isCompleted: hasInvoices
            ),
            FLOSetupTask(
                id: "mileage",
                title: "Set up mileage tracking",
                subtitle: "Maximize your deductions",
                icon: "car.fill",
                iconColor: .mint,
                isCompleted: hasMileageTrips || hasMileageSetupCompleted
            )
        ]
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if showingAllComplete {
                // All complete celebration state
                allCompleteView
            } else if shouldShowCard {
                // Normal card with tasks
                cardContent
            }
        }
        .onChange(of: allTasksCompleted) { _, isComplete in
            if isComplete && !showingAllComplete {
                // Show completion state
                HapticService.play(.success)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showingAllComplete = true
                }
                // Auto-dismiss after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        hasDismissed = true
                    }
                }
            }
        }
        // Sheet presentations
        .sheet(isPresented: $showingBudgetList) {
            NavigationStack {
                BudgetListView()
            }
        }
        .sheet(isPresented: $showingMileageSetup) {
            NavigationStack {
                MileageTrackingMainView()
            }
        }
        .sheet(isPresented: $showingClientManagement) {
            NavigationStack {
                ClientListView()
            }
        }
        .sheet(isPresented: $showingInvoiceCreate) {
            NavigationStack {
                CreateInvoiceView()
            }
        }
        .sheet(isPresented: $showingAccountsView) {
            NavigationStack {
                AccountsView()
            }
        }
        .sheet(isPresented: $showingReportsView) {
            NavigationStack {
                ReportsView()
            }
        }
        .sheet(isPresented: $showingTaxSettings) {
            NavigationStack {
                TaxSettingsView()
            }
        }
        .sheet(isPresented: $showingBusinessProfile) {
            NavigationStack {
                BusinessProfileSettingsView()
            }
        }
        .task {
            checkCompletionStatus()
        }
        // v3.4.2: Demo data seeds asynchronously and can finish AFTER this .task
        // ran, leaving the checklist at "0 of N". Re-check when seeding completes
        // so the seeded Pro scenario resolves to "You're all set!" on first load.
        .onReceive(NotificationCenter.default.publisher(for: .demoDataSeeded)) { _ in
            checkCompletionStatus()
        }
        // Re-check completion when any sheet dismisses (user may have created data)
        .onChange(of: showingAddTransaction) { _, isShowing in
            if !isShowing { checkCompletionStatus() }
        }
        .onChange(of: showingReceiptScanner) { _, isShowing in
            if !isShowing { checkCompletionStatus() }
        }
        .onChange(of: showingBudgetList) { _, isShowing in
            if !isShowing { checkCompletionStatus() }
        }
        .onChange(of: showingAccountsView) { _, isShowing in
            if !isShowing { checkCompletionStatus() }
        }
        .onChange(of: showingTaxSettings) { _, isShowing in
            if !isShowing { checkCompletionStatus() }
        }
        .onChange(of: showingClientManagement) { _, isShowing in
            if !isShowing { checkCompletionStatus() }
        }
        .onChange(of: showingInvoiceCreate) { _, isShowing in
            if !isShowing { checkCompletionStatus() }
        }
        .onChange(of: showingMileageSetup) { _, isShowing in
            if !isShowing { checkCompletionStatus() }
        }
        .onChange(of: showingBusinessProfile) { _, isShowing in
            if !isShowing { checkCompletionStatus() }
        }
    }

    // MARK: - Completion Status Check

    /// Uses fetchCount for O(1) existence checks — no object deserialization needed.
    /// Replaces 9 @Query declarations that each triggered full deserialization passes.
    private func checkCompletionStatus() {
        hasTransactions = (try? modelContext.fetchCount(FetchDescriptor<Transaction>())) ?? 0 > 0
        hasBudgets = (try? modelContext.fetchCount(FetchDescriptor<Budget>())) ?? 0 > 0
        hasAccounts = (try? modelContext.fetchCount(FetchDescriptor<Account>())) ?? 0 > 0
        hasTaxSettings = (try? modelContext.fetchCount(FetchDescriptor<TaxSettings>())) ?? 0 > 0
        hasClients = (try? modelContext.fetchCount(FetchDescriptor<Client>())) ?? 0 > 0
        hasInvoices = (try? modelContext.fetchCount(FetchDescriptor<Invoice>())) ?? 0 > 0
        hasReceipts = (try? modelContext.fetchCount(FetchDescriptor<ReceiptData>())) ?? 0 > 0
        hasBusinessProfiles = (try? modelContext.fetchCount(FetchDescriptor<BusinessProfile>())) ?? 0 > 0
        hasMileageTrips = (try? modelContext.fetchCount(FetchDescriptor<MileageTrip>())) ?? 0 > 0
    }
    
    // MARK: - Card Content
    
    private var cardContent: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            if isExpanded {
                // Task list
                VStack(spacing: 8) {
                    ForEach(visibleTasks) { task in
                        taskRow(task)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.9).combined(with: .opacity),
                                removal: .scale(scale: 0.8)
                                    .combined(with: .opacity)
                                    .combined(with: .move(edge: .leading))
                            ))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: visibleTasks.count)
            }
        }
        .background(Color.floSystemBackground)
        .cornerRadius(16)
        .floCardShadow(y: 4)
        .opacity(viewAppeared ? 1 : 0.001)
        .offset(y: viewAppeared ? 0 : 20)
        .onAppear {
            withAnimation(FLOAnimation.standard) {
                viewAppeared = true
            }
        }
    }
    
    // MARK: - All Complete View
    
    private var allCompleteView: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.brandPrimary)
                    .frame(width: 40, height: 40)
                
                Image(systemName: "checkmark")
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("You're all set!")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.primary)
                
                Text("Great job completing your setup")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.floSystemBackground)
        .cornerRadius(16)
        .floCardShadow(y: 4)
        .transition(.scale(scale: 0.95).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Setup complete! You're all set. Great job completing your setup.")
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Getting Started")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.primary)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text("\(completedCount) of \(totalCount) completed")
                        .font(.caption)
                        .fontWeight(.medium)  // Slightly bolder for better contrast
                        .foregroundStyle(.primary.opacity(0.65))  // Darker than .secondary for WCAG
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Getting Started, \(completedCount) of \(totalCount) tasks completed")
                
                Spacer()
                
                // Expand/Collapse
                Button {
                    withAnimation(FLOAnimation.standard) {
                        isExpanded.toggle()
                    }
                    HapticService.play(.light)
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(Circle())
                }
                .accessibilityLabel(isExpanded ? "Collapse getting started" : "Expand getting started")
                .accessibilityHint("Double tap to \(isExpanded ? "hide" : "show") setup tasks")
                
                // Dismiss
                Button {
                    withAnimation(FLOAnimation.standard) {
                        hasDismissed = true
                    }
                    HapticService.play(.light)
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Dismiss getting started")
                .accessibilityHint("Double tap to hide this card permanently")
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color.brandPrimary, Color.brandAccent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 8)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 8)
            .accessibilityHidden(true)  // Parent card announces progress; this is decorative
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    Color.brandPrimary.opacity(0.08),
                    Color.brandAccent.opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
    
    // MARK: - Task Row
    
    private func taskRow(_ task: FLOSetupTask) -> some View {
        Button {
            handleTaskTap(task)
        } label: {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(task.iconColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: task.icon)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(task.iconColor)
                }
                .accessibilityHidden(true)
                
                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    Text(task.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.floSecondarySystemBackground)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(task.title). \(task.subtitle)")
        .accessibilityHint("Double tap to start this task")
        .accessibilityAddTraits(.isButton)
    }
    
    // MARK: - Task Actions
    
    private func handleTaskTap(_ task: FLOSetupTask) {
        HapticService.play(.light)
        
        switch task.id {
        case "account":
            showingAccountsView = true
            
        case "transaction":
            showingAddTransaction = true
            
        case "receipt":
            showingReceiptScanner = true
            
        case "tax_profile":
            showingTaxSettings = true

        case "business_profile":
            showingBusinessProfile = true
            
        case "bank_account":
            showingAccountsView = true
            
        case "budget":
            showingBudgetList = true
            
        case "client":
            showingClientManagement = true
            
        case "invoice":
            showingInvoiceCreate = true
            
        case "mileage":
            showingMileageSetup = true
            
        case "reports":
            hasExploredReports = true
            showingReportsView = true
            
        default:
            break
        }
    }
}

// MARK: - Setup Task Model

struct FLOSetupTask: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let isCompleted: Bool
    
    static func == (lhs: FLOSetupTask, rhs: FLOSetupTask) -> Bool {
        lhs.id == rhs.id && lhs.isCompleted == rhs.isCompleted
    }
}

// MARK: - Preview

#Preview("Getting Started - Free") {
    VStack {
        GettingStartedCard(
            showingAddTransaction: .constant(false),
            showingReceiptScanner: .constant(false)
        )
        .padding()
        .environmentObject(SubscriptionManager.shared)
        
        Spacer()
    }
    .background(Color.floSystemGroupedBackground)
    .modelContainer(for: [Transaction.self, Budget.self, Account.self, TaxSettings.self, Client.self, Invoice.self, ReceiptData.self], inMemory: true)
}
