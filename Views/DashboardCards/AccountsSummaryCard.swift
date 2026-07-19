//  AccountsSummaryCard.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.1 - Defensive AccountRowCompact to prevent deletion crashes
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v3.1:
//  ✅ FIXED: Crash when accessing account properties after deletion
//  ✅ ADDED: @State caching of account properties in AccountRowCompact
//  ✅ ADDED: modelContext check to detect deleted accounts
//  ✅ ADDED: Graceful fallback when account is invalid
//
//  CHANGES v3.0:
//  - Custom SwiftUI empty state illustration
//
//  CHANGES v2.4:
//  - Fixed "Net Worth" label contrast (was .secondary, now .primary.opacity(0.65))
//  - Fixed financeModeLabel contrast
//  - Uses fontWeight(.medium) + .primary.opacity(0.65) for WCAG AA compliance
//
//  CHANGES v2.3:
//  - Fixed text clipping at large Dynamic Type sizes throughout card
//  - Added lineLimit(1) and minimumScaleFactor to: account names, account numbers,
//    balances, net worth, total assets, total liabilities, institution names
//  - Prevents "Text clipped" accessibility audit failures
//
//  CHANGES v2.2:
//  ✅ Added VoiceOver labels for all account balances
//  ✅ Net worth announced with context (positive/negative)
//  ✅ Privacy veil state announced ("balances hidden, tap to reveal")
//  ✅ Account rows read name, type, and balance
//  ✅ Assets and liabilities summarized for screen readers
//  ✅ Empty state and hidden accounts properly announced
//  ✅ Navigation hints for See All button
//
//  CHANGES v2.1:
//  - Added privacy veil with blur effect over financial amounts
//  - Tap anywhere on card to reveal balances (blur animates away)
//  - Resets to blurred state when dashboard is left (via onDisappear)
//  - Added "Hide Balances on Dashboard" setting support
//  - Setting stored in UserDefaults, configurable in AccountsView
//  - "Tap to reveal" hint shown when veiled
//  - Headers and account names remain visible, only amounts blur
//
//  CHANGES v2.0:
//  - Added financeMode parameter to filter accounts by business/personal
//  - Respects showOnDashboard toggle on accounts
//  - Fixed UTF-8 encoding issues
//  - Improved empty state messaging per finance mode
//
//  FEATURES:
//  - Shows active accounts filtered by dashboard mode
//  - Net worth calculation (assets - liabilities)
//  - Color-coded balance indicators
//  - Animated entrance and values
//  - Navigation to full AccountsView
//  - Subscription tier aware (Premium+)
//  - HapticService integration
//

import SwiftUI
import FLODesignSystem
import SwiftData

struct AccountsSummaryCard: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Query(sort: \Account.name) private var allAccounts: [Account]
    
    /// Finance mode passed from DashboardView to filter accounts
    let financeMode: FinanceMode
    
    @State private var cardVisible = false
    @State private var balancesAnimated = false
    
    // MARK: - Privacy Veil State
    /// Whether the balances are currently hidden (blurred)
    @State private var isVeiled = true
    
    /// User setting: if true, balances are always hidden until tapped
    @AppStorage("hideBalancesOnDashboard") private var hideBalancesOnDashboard = true
    
    /// Blur radius for the privacy veil
    private var blurRadius: CGFloat {
        (isVeiled && hideBalancesOnDashboard) ? 12 : 0
    }
    
    // MARK: - Computed Properties
    
    /// Accounts filtered by finance mode and dashboard visibility
    private var filteredAccounts: [Account] {
        let active = allAccounts.filter { $0.isActive && $0.showOnDashboard }
        
        switch financeMode {
        case .business:
            return active.filter { $0.financeType == .business }
        case .personal:
            return active.filter { $0.financeType == .personal }
        case .all:
            return active
        }
    }
    
    private var topAccounts: [Account] {
        // Show up to 4 accounts, prioritizing primary accounts first
        let sorted = filteredAccounts.sorted { a, b in
            if a.isPrimary != b.isPrimary {
                return a.isPrimary
            }
            return abs(a.currentBalance) > abs(b.currentBalance)
        }
        return Array(sorted.prefix(4))
    }
    
    private var totalAssets: Double {
        filteredAccounts.filter { $0.isAsset }.reduce(0) { $0 + $1.currentBalance }
    }
    
    private var totalLiabilities: Double {
        filteredAccounts.filter { $0.isLiability }.reduce(0) { $0 + abs($1.currentBalance) }
    }
    
    private var netWorth: Double {
        totalAssets - totalLiabilities
    }
    
    private var hasAccounts: Bool {
        !filteredAccounts.isEmpty
    }
    
    /// Count of hidden accounts for this mode
    private var hiddenAccountCount: Int {
        let active = allAccounts.filter { $0.isActive && !$0.showOnDashboard }
        switch financeMode {
        case .business:
            return active.filter { $0.financeType == .business }.count
        case .personal:
            return active.filter { $0.financeType == .personal }.count
        case .all:
            return active.count
        }
    }
    
    /// Whether the veil should be shown
    private var shouldShowVeil: Bool {
        isVeiled && hideBalancesOnDashboard && hasAccounts
    }
    
    // MARK: - Accessibility Labels
    
    private var cardAccessibilityLabel: String {
        if shouldShowVeil {
            return "Accounts summary. Balances hidden for privacy. Tap to reveal."
        }
        
        var label = "\(financeModeLabel). "
        
        if hasAccounts {
            label += "Net worth: \(netWorth.accessibilityCurrency). "
            label += "Total assets: \(totalAssets.accessibilityCurrency). "
            label += "Total liabilities: \(totalLiabilities.accessibilityCurrency). "
            label += "\(filteredAccounts.count) account\(filteredAccounts.count == 1 ? "" : "s")."
        } else {
            label += emptyStateTitle
        }
        
        return label
    }
    
    // MARK: - Body
    
    var body: some View {
        // Only show for Premium+ users with balance tracking
        if subscriptionManager.currentTier.hasBalanceTracking {
            VStack(spacing: 0) {
                // Header
                headerView
                
                Divider()
                    .accessibilityHidden(true)
                
                // Content
                if hasAccounts {
                    accountsContent
                } else {
                    emptyStateContent
                }
            }
            .background(Color.floSecondarySystemBackground)
            .cornerRadius(12)
            .floCardShadow()
            .contentShape(Rectangle()) // Make entire card tappable
            .onTapGesture {
                revealBalances()
            }
            .onAppear {
                animateEntrance()
                // Reset veil state when card appears
                isVeiled = true
            }
            .onDisappear {
                // Reset veil when leaving dashboard
                isVeiled = true
            }
            .onChange(of: financeMode) { _, _ in
                // Re-animate when mode changes
                withAnimation(FLOAnimation.quick) {
                    balancesAnimated = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(FLOAnimation.standard) {
                        balancesAnimated = true
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(cardAccessibilityLabel)
            .accessibilityHint(shouldShowVeil ? "Double tap to reveal balances" : "")
        }
    }
    
    // MARK: - Reveal Action
    
    private func revealBalances() {
        guard shouldShowVeil else { return }
        
        HapticService.play(.light)
        
        withAnimation(.easeOut(duration: 0.3)) {
            isVeiled = false
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            FLOBrandedIcon(icon: .accounts, size: .medium, color: .brandPrimary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Accounts")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                
                Text(financeModeLabel)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)  // Full contrast for WCAG compliance
            }
            
            Spacer()
            
            Button {
                HapticService.play(.light)
                NavigationService.shared.selectedTab = .accounts
            } label: {
                HStack(spacing: 4) {
                    Text("See All")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("See all accounts")
            .accessibilityHint("Switches to Accounts tab")
        }
        .padding()
        .opacity(cardVisible ? 1 : 0.001)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
    
    private var financeModeLabel: String {
        switch financeMode {
        case .business:
            return "Business accounts"
        case .personal:
            return "Personal accounts"
        case .all:
            return "All accounts"
        }
    }
    
    // MARK: - Accounts Content
    
    private var accountsContent: some View {
        ZStack {
            VStack(spacing: 12) {
                // Net Worth Summary
                netWorthRow
                
                Divider()
                    .padding(.horizontal)
                    .accessibilityHidden(true)
                
                // Account Rows
                ForEach(Array(topAccounts.enumerated()), id: \.element.id) { index, account in
                    AccountRowCompact(
                        account: account,
                        animationDelay: Double(index) * 0.05,
                        isVisible: balancesAnimated,
                        isBlurred: shouldShowVeil,
                        blurRadius: blurRadius
                    )
                    
                    if account.id != topAccounts.last?.id {
                        Divider()
                            .padding(.leading, 52)
                            .accessibilityHidden(true)
                    }
                }
                
                // Show more indicator if there are more accounts
                if filteredAccounts.count > 4 {
                    moreAccountsIndicator
                }
                
                // Hidden accounts indicator
                if hiddenAccountCount > 0 {
                    hiddenAccountsIndicator
                }
            }
            .padding(.vertical, 12)
            
            // "Tap to reveal" hint overlay
            if shouldShowVeil {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "hand.tap.fill")
                            .font(.caption)
                            .accessibilityHidden(true)
                        Text("Tap to reveal balances")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(
                        Capsule()
                            .fill(Color.floSystemBackground.opacity(0.9))
                            .floCardShadow(radius: 4)
                    )
                    .padding(.bottom, 8)
                    .accessibilityHidden(true) // Announced in card label
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
    }
    
    // MARK: - Net Worth Row
    
    private var netWorthRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(netWorthLabel)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                
                Text(netWorth, format: .currency(code: "USD"))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(netWorth >= 0 ? Color.brandPrimary : Color.expenseRed)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.numericText(value: netWorth))
                    .blur(radius: blurRadius)
                    .animation(.easeOut(duration: 0.3), value: blurRadius)
                    .accessibleCurrency(netWorth, label: netWorthLabel)
                    .accessibilityAddTraits(.updatesFrequently)
            }
            
            Spacer()
            
            // Assets & Liabilities mini summary
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.incomeGreen)
                        .accessibilityHidden(true)
                    Text(totalAssets, format: .currency(code: "USD"))
                        .font(.caption)
                        .foregroundStyle(Color.primary)  // Maximum contrast
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .blur(radius: blurRadius)
                        .animation(.easeOut(duration: 0.3), value: blurRadius)
                        .accessibleCurrency(totalAssets, label: "Total assets")
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.expenseRed)
                        .accessibilityHidden(true)
                    Text(totalLiabilities, format: .currency(code: "USD"))
                        .font(.caption)
                        .foregroundStyle(Color.primary)  // Maximum contrast
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .blur(radius: blurRadius)
                        .animation(.easeOut(duration: 0.3), value: blurRadius)
                        .accessibleCurrency(totalLiabilities, label: "Total liabilities")
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.floSystemBackground)  // White background for contrast
        .opacity(balancesAnimated ? 1 : 0.001)
        .offset(y: balancesAnimated ? 0 : 10)
        .animation(FLOAnimation.standard, value: balancesAnimated)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(netWorthAccessibilityLabel)
    }
    
    private var netWorthLabel: String {
        switch financeMode {
        case .business:
            return "Business Net Worth"
        case .personal:
            return "Personal Net Worth"
        case .all:
            return "Net Worth"
        }
    }
    
    private var netWorthAccessibilityLabel: String {
        if shouldShowVeil {
            return "\(netWorthLabel): Hidden"
        }
        
        let status = netWorth >= 0 ? "positive" : "negative"
        return "\(netWorthLabel): \(netWorth.accessibilityCurrency), \(status). Assets: \(totalAssets.accessibilityCurrency). Liabilities: \(totalLiabilities.accessibilityCurrency)"
    }
    
    // MARK: - More Accounts Indicator
    
    private var moreAccountsIndicator: some View {
        HStack {
            Spacer()
            Text("+\(filteredAccounts.count - 4) more accounts")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.top, 4)
        .opacity(balancesAnimated ? 1 : 0.001)
        .accessibilityLabel("\(filteredAccounts.count - 4) more accounts not shown")
    }
    
    // MARK: - Hidden Accounts Indicator
    
    private var hiddenAccountsIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "eye.slash")
                .font(.caption2)
                .accessibilityHidden(true)
            Text("\(hiddenAccountCount) account\(hiddenAccountCount == 1 ? "" : "s") hidden from dashboard")
                .font(.caption)
        }
        .foregroundStyle(.tertiary)
        .padding(.top, 4)
        .opacity(balancesAnimated ? 1 : 0.001)
        .accessibilityLabel("\(hiddenAccountCount) account\(hiddenAccountCount == 1 ? "" : "s") hidden from dashboard. Configure in Accounts settings.")
    }
    
    // MARK: - Empty State
    
    private var emptyStateContent: some View {
        VStack(spacing: 12) {
            AccountsIllustration()
                .scaleEffect(0.75)
                .frame(height: 105)
                .accessibilityHidden(true)
            
            Text(emptyStateTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            if hiddenAccountCount > 0 {
                Text("\(hiddenAccountCount) account\(hiddenAccountCount == 1 ? " is" : "s are") hidden from dashboard")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            Button {
                HapticService.play(.medium)
                NavigationService.shared.selectedTab = .accounts
            } label: {
                Text("Add Account")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.brandPrimary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add new account")
            .accessibilityHint("Switches to Accounts tab")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .opacity(cardVisible ? 1 : 0.001)
        .accessibilityElement(children: .contain)
    }
    
    private var emptyStateTitle: String {
        switch financeMode {
        case .business:
            return "No business accounts"
        case .personal:
            return "No personal accounts"
        case .all:
            return "No accounts yet"
        }
    }
    
    // MARK: - Animations
    
    private func animateEntrance() {
        withAnimation(FLOAnimation.standard) {
            cardVisible = true
        }
        
        withAnimation(FLOAnimation.gentle.delay(0.2)) {
            balancesAnimated = true
        }
    }
}

// MARK: - Account Row Compact (Defensive Version)

/// A compact row displaying account info with defensive coding to prevent crashes during deletion.
/// Caches account properties in @State to survive SwiftData deletions mid-render.
struct AccountRowCompact: View {
    let account: Account
    var animationDelay: Double = 0
    var isVisible: Bool = true
    var isBlurred: Bool = false
    var blurRadius: CGFloat = 0
    
    // MARK: - Cached State (Defensive against deletion)
    // These @State properties cache account values to prevent crashes
    // when the account is deleted while the view is still rendering
    
    @State private var cachedName: String = ""
    @State private var cachedColor: String = "#14B8A6"
    @State private var cachedIcon: String = "building.columns"
    @State private var cachedBalance: Double = 0
    @State private var cachedIsPrimary: Bool = false
    @State private var cachedIsLiability: Bool = false
    @State private var cachedFinanceType: Transaction.FinanceType = .personal
    @State private var cachedLastFourDigits: String? = nil
    @State private var cachedInstitutionName: String? = nil
    @State private var cachedAccountType: String = "checking"
    @State private var isAccountValid: Bool = true
    
    private var accessibilityLabel: String {
        guard isAccountValid else { return "Account unavailable" }
        
        var label = cachedName
        
        if cachedIsPrimary {
            label += ", primary account"
        }
        
        label += ", \(cachedFinanceType == .business ? "business" : "personal")"
        label += ", \(cachedAccountType)"
        
        if isBlurred {
            label += ", balance hidden"
        } else {
            label += ", balance: \(cachedBalance.accessibilityCurrency)"
            if cachedIsLiability && cachedBalance < 0 {
                label += " owed"
            }
        }
        
        return label
    }
    
    var body: some View {
        Group {
            if isAccountValid {
                accountContent
            } else {
                // Graceful fallback for deleted accounts
                EmptyView()
            }
        }
        .onAppear {
            cacheAccountValues()
        }
        .onChange(of: account.id) { _, _ in
            cacheAccountValues()
        }
    }
    
    // MARK: - Main Content
    
    private var accountContent: some View {
        HStack(spacing: 12) {
            // Account Icon
            ZStack {
                Circle()
                    .fill(Color(hex: cachedColor).opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: cachedIcon)
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: cachedColor))
            }
            .accessibilityHidden(true)
            
            // Account Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(cachedName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    if cachedIsPrimary {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                            .accessibilityHidden(true)
                    }
                }
                
                HStack(spacing: 4) {
                    // Finance type indicator
                    Image(systemName: cachedFinanceType == .business ? "briefcase.fill" : "person.fill")
                        .font(.caption2)
                        .foregroundStyle(cachedFinanceType == .business ? Color.businessColor : Color.personalColor)
                        .accessibilityHidden(true)
                    
                    if let digits = cachedLastFourDigits, !digits.isEmpty {
                        Text("•••• \(digits)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    } else if let institution = cachedInstitutionName {
                        Text(institution)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
            
            Spacer()
            
            // Balance with blur support
            Text(cachedBalance, format: .currency(code: "USD"))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(balanceColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .blur(radius: blurRadius)
                .animation(.easeOut(duration: 0.3), value: blurRadius)
                .accessibleCurrency(cachedBalance, label: "\(cachedName) balance")
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .opacity(isVisible ? 1 : 0.001)
        .offset(x: isVisible ? 0 : -10)
        .animation(FLOAnimation.standard.delay(animationDelay), value: isVisible)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }
    
    // MARK: - Helpers
    
    private var balanceColor: Color {
        if cachedIsLiability {
            return cachedBalance < 0 ? Color.expenseRed : Color.incomeGreen
        } else {
            return cachedBalance >= 0 ? Color.primary : Color.expenseRed
        }
    }
    
    /// Safely cache account values to prevent crashes during deletion
    private func cacheAccountValues() {
        // Check if account's modelContext is nil (indicates deletion)
        guard account.modelContext != nil else {
            isAccountValid = false
            return
        }
        
        // Safely cache all values we need for rendering
        // This prevents crashes if the account is deleted mid-render
        cachedName = account.name
        cachedColor = account.colorHex ?? account.accountType.color
        cachedIcon = account.accountType.icon
        cachedBalance = account.currentBalance
        cachedIsPrimary = account.isPrimary
        cachedIsLiability = !account.accountType.isAsset
        cachedFinanceType = account.financeType
        cachedLastFourDigits = account.lastFourDigits
        cachedInstitutionName = account.institutionName
        cachedAccountType = account.accountType.rawValue
        isAccountValid = true
    }
}


// NOTE: Color(hex:) is defined in SubscriptionView.swift

// MARK: - Preview

#Preview("Veiled State") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Account.self, Transaction.self, configurations: config)
    
    let context = container.mainContext
    
    let checking = Account(name: "Business Checking", accountType: .checking, isPrimary: true, currentBalance: 12450.00, financeType: .business, lastFourDigits: "4521", institutionName: "Chase")
    let creditCard = Account(name: "Business Card", accountType: .creditCard, currentBalance: -890.00, financeType: .business, lastFourDigits: "1234")
    
    context.insert(checking)
    context.insert(creditCard)
    
    return NavigationStack {
        ScrollView {
            AccountsSummaryCard(financeMode: .business)
                .padding()
        }
        .background(Color.floSystemGroupedBackground)
    }
    .modelContainer(container)
    .environmentObject(SubscriptionManager.shared)
}

#Preview("Personal Mode") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Account.self, Transaction.self, configurations: config)
    
    let context = container.mainContext
    
    let personal = Account(name: "Personal Checking", accountType: .checking, isPrimary: true, currentBalance: 3200.00, financeType: .personal, institutionName: "Ally")
    let savings = Account(name: "Savings", accountType: .savings, currentBalance: 15000.00, financeType: .personal)
    let hiddenCard = Account(name: "Hidden Card", accountType: .creditCard, showOnDashboard: false, currentBalance: -500.00, financeType: .personal)
    
    context.insert(personal)
    context.insert(savings)
    context.insert(hiddenCard)
    
    return NavigationStack {
        ScrollView {
            AccountsSummaryCard(financeMode: .personal)
                .padding()
        }
        .background(Color.floSystemGroupedBackground)
    }
    .modelContainer(container)
    .environmentObject(SubscriptionManager.shared)
}

#Preview("All Accounts") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Account.self, Transaction.self, configurations: config)
    
    let context = container.mainContext
    
    let checking = Account(name: "Business Checking", accountType: .checking, isPrimary: true, currentBalance: 12450.00, financeType: .business, lastFourDigits: "4521", institutionName: "Chase")
    let creditCard = Account(name: "Business Card", accountType: .creditCard, currentBalance: -890.00, financeType: .business, lastFourDigits: "1234")
    let personal = Account(name: "Personal Checking", accountType: .checking, currentBalance: 3200.00, financeType: .personal, institutionName: "Ally")
    let cash = Account(name: "Cash", accountType: .cash, currentBalance: 150.00, financeType: .personal)
    
    context.insert(checking)
    context.insert(creditCard)
    context.insert(personal)
    context.insert(cash)
    
    return NavigationStack {
        ScrollView {
            AccountsSummaryCard(financeMode: .all)
                .padding()
        }
        .background(Color.floSystemGroupedBackground)
    }
    .modelContainer(container)
    .environmentObject(SubscriptionManager.shared)
}

#Preview("Empty State") {
    return NavigationStack {
        ScrollView {
            AccountsSummaryCard(financeMode: .all)
                .padding()
        }
        .background(Color.floSystemGroupedBackground)
    }
    .modelContainer(for: Account.self, inMemory: true)
    .environmentObject(SubscriptionManager.shared)
}
