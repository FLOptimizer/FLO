//  PlaidLinkView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.6 - VoiceOver Audit: Critical bank linking flow accessibility
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.6 - VoiceOver Audit (CRITICAL FLOW):
//  ✅ ADDED: Loading view accessibility label and state announcement
//  ✅ ADDED: Error view button hints explaining recovery actions
//  ✅ ADDED: Error state accessibility labels with clear explanations
//  ✅ ADDED: ConnectBankButton proper labels for all button styles
//  ✅ ADDED: ConnectBankButton icons hidden (decorative)
//  ✅ ADDED: PlaidSyncStatusView status as accessibilityValue
//  ✅ ADDED: PlaidSyncStatusView sync button label and hint
//  ✅ ADDED: PlaidSyncStatusView progress bar accessibilityValue with count
//  ✅ ADDED: Success/error state announcements for VoiceOver
//  ✅ ADDED: ConnectedAccountsCard icons hidden
//  ✅ ADDED: AccountRowView context menu item labels
//  ✅ ADDED: Screen change announcements throughout flow
//  ✅ NOTE: This is a CRITICAL flow - blind users must be able to link banks independently
//
//  CHANGES v1.5 - Dynamic Type Verification:
//  ✅ FIXED: Loading view "Connecting to your bank" title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Loading view "This may take a moment" subtitle missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Error view "Connection Failed" title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Error view description text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Error view recovery suggestion missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Error view "Try Again" button text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Error view "Cancel" button text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Alert message text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: ConnectBankButton labels missing lineLimit + minimumScaleFactor
//  ✅ FIXED: PlaidSyncStatusView status text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: PlaidSyncStatusView result text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: ConnectedAccountsCard "Manage" link missing lineLimit + minimumScaleFactor
//  ✅ FIXED: ConnectedAccountsCard empty state text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: ConnectedAccountsCard account name missing lineLimit + minimumScaleFactor
//  ✅ FIXED: ConnectedAccountsCard institution name missing lineLimit + minimumScaleFactor
//  ✅ FIXED: ConnectedAccountsCard "more accounts" text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: ConnectedAccountsCard sync status text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: AccountRowView account name missing lineLimit + minimumScaleFactor
//  ✅ FIXED: AccountRowView institution name missing lineLimit + minimumScaleFactor
//  ✅ FIXED: AccountRowView status text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Disconnect alert message missing lineLimit + minimumScaleFactor
//
//  CHANGES v1.4:
//  ✅ Activated LinkKit SDK import (was commented out)
//  ✅ Replaced mock PlaidLinkRepresentable with live LinkKit integration
//  ✅ Added Coordinator pattern for Handler lifecycle management
//  ✅ Renamed FLO's LinkEvent → FLOLinkEvent to avoid LinkKit conflict
//  ✅ UTF-8 cleanup
//
//  PURPOSE:
//  SwiftUI wrapper for Plaid Link SDK that provides:
//  - Native SwiftUI integration using UIViewControllerRepresentable
//  - Handling of success, exit, and event callbacks
//  - Support for initial link and update/reauth flows
//  - Seamless integration with FLO's design system
//
//  CHANGES v1.2:
//  - Removed unnecessary await from loadState() calls
//  - Fixed array conversion for ForEach
//  - Added explicit type annotation for closure parameters
//
//  CHANGES v1.1:
//  - Fixed LinkEvent Sendable conformance
//  - Fixed MainActor patterns

import SwiftUI
import SwiftData
import LinkKit

// MARK: - Plaid Link View

/// SwiftUI view that wraps Plaid Link SDK
struct PlaidLinkView: View {
    
    // MARK: - Environment
    
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @SwiftUI.Environment(\.modelContext) private var modelContext
    
    // MARK: - State
    
    @StateObject private var viewModel: PlaidLinkViewModel
    @State private var showingError = false
    
    // MARK: - Callbacks
    
    let onSuccess: (LinkMetadata) -> Void
    let onExit: (PlaidError?) -> Void
    
    // MARK: - Initialization
    
    init(
        linkToken: String,
        onSuccess: @escaping (LinkMetadata) -> Void,
        onExit: @escaping (PlaidError?) -> Void
    ) {
        self._viewModel = StateObject(wrappedValue: PlaidLinkViewModel(linkToken: linkToken))
        self.onSuccess = onSuccess
        self.onExit = onExit
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Loading/presenting state
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.error {
                errorView(error)
            } else {
                // Plaid Link will be presented as a full-screen cover
                PlaidLinkRepresentable(
                    linkToken: viewModel.linkToken,
                    onSuccess: handleSuccess,
                    onExit: handleExit,
                    onEvent: handleEvent
                )
            }
        }
        .background(Color(uiColor: .systemBackground))
        .alert("Connection Error", isPresented: $showingError) {
            Button("Try Again") {
                viewModel.retry()
            }
            Button("Cancel", role: .cancel) {
                dismiss()
            }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "An error occurred")
                .lineLimit(3)
                .minimumScaleFactor(0.7)
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Connecting to your bank...")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.secondary)
            
            Text("This may take a moment")
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connecting to your bank. This may take a moment.")
        .accessibilityAddTraits(.updatesFrequently)
        .onAppear {
            AccessibilityAnnouncement.announce("Connecting to your bank through Plaid")
        }
    }
    
    // MARK: - Error View
    
    private func errorView(_ error: PlaidError) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            
            Text("Connection Failed")
                .font(.title2)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .fontWeight(.semibold)
            
            Text(error.localizedDescription)
                .font(.body)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            if let recovery = error.recoverySuggestion {
                Text(recovery)
                    .font(.callout)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            VStack(spacing: 12) {
                Button {
                    viewModel.retry()
                } label: {
                    Text("Try Again")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.brandPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityLabel("Try connecting again")
                .accessibilityHint("Double tap to retry connecting your bank account")
                
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                         .foregroundStyle(Color.brandPrimaryText)
                }
                .accessibilityLabel("Cancel connection")
                .accessibilityHint("Double tap to close and return")
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .onAppear {
            AccessibilityAnnouncement.announce("Bank connection failed. \(error.localizedDescription)")
        }
    }
    
    // MARK: - Handlers
    
    private func handleSuccess(_ metadata: LinkMetadata) {
        HapticService.play(.success)
        AccessibilityAnnouncement.announce("Bank connected successfully. Syncing transactions.")
        onSuccess(metadata)
        dismiss()
    }
    
    private func handleExit(_ error: PlaidError?) {
        if error != nil {
            HapticService.play(.error)
        } else {
            HapticService.play(.light)
        }
        onExit(error)
        dismiss()
    }
    
    private func handleEvent(_ event: FLOLinkEvent) {
        // Log events for debugging/analytics
        print("🔗 Plaid Link Event: \(event.name)")
        
        // Provide haptic feedback for certain events
        switch event.name {
        case "HANDOFF":
            HapticService.play(.medium)
        case "SUBMIT_CREDENTIALS":
            HapticService.play(.light)
        case "SELECT_INSTITUTION":
            HapticService.play(.selection)
        default:
            break
        }
    }
}

// MARK: - View Model

@MainActor
final class PlaidLinkViewModel: ObservableObject {
    
    @Published var isLoading = false
    @Published var error: PlaidError?
    
    let linkToken: String
    
    init(linkToken: String) {
        self.linkToken = linkToken
    }
    
    func retry() {
        error = nil
        isLoading = true
        
        // Brief delay to show loading state
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            isLoading = false
        }
    }
}

// MARK: - UIViewControllerRepresentable

/// Wraps Plaid Link SDK's view controller for SwiftUI
struct PlaidLinkRepresentable: UIViewControllerRepresentable {
    
    let linkToken: String
    let onSuccess: (LinkMetadata) -> Void
    let onExit: (PlaidError?) -> Void
    let onEvent: (FLOLinkEvent) -> Void
    
    // MARK: - Coordinator
    
    /// Coordinator holds a strong reference to the LinkKit Handler
    /// to prevent premature deallocation during the Link flow
    class Coordinator {
        var handler: Handler?
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    // MARK: - UIViewControllerRepresentable
    
    func makeUIViewController(context: Context) -> UIViewController {
        let container = UIViewController()
        container.view.backgroundColor = .clear
        
        // Capture callbacks for use in closures
        let successCallback = onSuccess
        let exitCallback = onExit
        let eventCallback = onEvent
        
        // Build LinkKit configuration with explicit closure types
        var configuration = LinkTokenConfiguration(token: linkToken) { (success: LinkSuccess) in
            let metadata = LinkMetadata(
                publicToken: success.publicToken,
                institutionId: success.metadata.institution.id,
                institutionName: success.metadata.institution.name,
                accounts: success.metadata.accounts.map { (acct: LinkKit.Account) in
                    // Derive account type from subtype
                    let typeString = Self.accountTypeFromSubtype(acct.subtype)
                    let subtypeString = String(describing: acct.subtype)
                    
                    return LinkAccount(
                        id: acct.id,
                        name: acct.name,
                        mask: acct.mask ?? "",
                        type: typeString,
                        subtype: subtypeString
                    )
                }
            )
            successCallback(metadata)
        }
        
        configuration.onExit = { (exit: LinkExit) in
            let error: PlaidError? = exit.error.map { (err: ExitError) in
                PlaidError.linkTokenCreationFailed(err.errorMessage)
            }
            exitCallback(error)
        }
        
        configuration.onEvent = { (event: LinkKit.LinkEvent) in
            eventCallback(FLOLinkEvent(name: String(describing: event.eventName)))
        }
        
        // Create and store handler (Coordinator keeps strong reference)
        let result = Plaid.create(configuration)
        switch result {
        case .success(let handler):
            context.coordinator.handler = handler
            // Present after a brief delay to ensure view hierarchy is ready
            DispatchQueue.main.async {
                handler.open(presentUsing: .viewController(container))
            }
        case .failure(let error):
            exitCallback(.linkTokenCreationFailed(error.localizedDescription))
        }
        
        return container
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No updates needed
    }
    
    // MARK: - Helpers
    
    /// Maps LinkKit AccountSubtype to a general account type string
    private static func accountTypeFromSubtype(_ subtype: AccountSubtype) -> String {
        let subtypeStr = String(describing: subtype).lowercased()
        if subtypeStr.contains("checking") || subtypeStr.contains("savings") || subtypeStr.contains("money market") || subtypeStr.contains("cd") || subtypeStr.contains("hsa") {
            return "depository"
        } else if subtypeStr.contains("credit") {
            return "credit"
        } else if subtypeStr.contains("401") || subtypeStr.contains("ira") || subtypeStr.contains("brokerage") || subtypeStr.contains("mutual") {
            return "investment"
        } else if subtypeStr.contains("student") || subtypeStr.contains("mortgage") || subtypeStr.contains("auto") {
            return "loan"
        }
        return "other"
    }
}

// MARK: - Link Event

/// Represents an event from Plaid Link
struct FLOLinkEvent: Sendable {
    let name: String
    
    init(name: String) {
        self.name = name
    }
}

// MARK: - Connect Bank Button

/// Reusable button for initiating bank connection
struct ConnectBankButton: View {
    
    @SwiftUI.Environment(\.modelContext) private var modelContext
    
    @State private var showingPlaidLink = false
    @State private var linkToken: String?
    @State private var isLoading = false
    @State private var error: PlaidError?
    @State private var showingError = false
    @State private var showingSuccess = false
    @State private var isSyncing = false
    
    var style: ConnectBankButtonStyle = .prominent
    
    enum ConnectBankButtonStyle {
        case prominent
        case secondary
        case minimal
    }
    
    var body: some View {
        Button {
            connectBank()
        } label: {
            buttonLabel
        }
        .disabled(isLoading || isSyncing)
        .accessibilityLabel(accessibilityButtonLabel)
        .accessibilityHint("Double tap to connect your bank account through Plaid")
        .sheet(isPresented: $showingPlaidLink) {
            if let token = linkToken {
                PlaidLinkView(
                    linkToken: token,
                    onSuccess: handleLinkSuccess,
                    onExit: handleLinkExit
                )
            }
        }
        .alert("Connection Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(error?.localizedDescription ?? "Failed to connect bank")
                .lineLimit(3)
                .minimumScaleFactor(0.7)
        }
        .alert("Bank Connected!", isPresented: $showingSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your bank account has been linked. Transactions will sync automatically.")
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .task {
            loadSyncState()
        }
    }
    
    @ViewBuilder
    private var buttonLabel: some View {
        switch style {
        case .prominent:
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "building.columns.fill")
                        .accessibilityHidden(true)
                }
                Text(isLoading ? "Connecting..." : "Connect Bank")
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.brandPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
        case .secondary:
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                } else {
                    Image(systemName: "link.badge.plus")
                        .accessibilityHidden(true)
                }
                Text(isLoading ? "Connecting..." : "Link Account")
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
             .foregroundStyle(Color.brandPrimaryText)
            
        case .minimal:
            if isLoading {
                ProgressView()
            } else {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                     .foregroundStyle(Color.brandPrimaryText)
            }
        }
    }
    
    private var accessibilityButtonLabel: String {
        if isLoading {
            return "Connecting to bank"
        } else if isSyncing {
            return "Bank sync in progress"
        } else {
            switch style {
            case .prominent, .secondary:
                return "Connect bank account"
            case .minimal:
                return "Add bank account"
            }
        }
    }
    
    @MainActor
    private func loadSyncState() {
        isSyncing = PlaidService.shared.isSyncing
    }
    
    private func connectBank() {
        guard !isLoading else { return }
        
        isLoading = true
        HapticService.play(.medium)
        
        Task { @MainActor in
            do {
                linkToken = try await PlaidService.shared.createLinkToken()
                showingPlaidLink = true
            } catch let plaidError as PlaidError {
                error = plaidError
                showingError = true
                HapticService.play(.error)
            } catch {
                self.error = .networkError(error)
                showingError = true
                HapticService.play(.error)
            }
            isLoading = false
        }
    }
    
    private func handleLinkSuccess(_ metadata: LinkMetadata) {
        Task { @MainActor in
            do {
                // Exchange token and create account
                let itemId = try await PlaidService.shared.exchangePublicToken(
                    metadata.publicToken,
                    metadata: metadata
                )
                
                // Create FLO accounts for linked accounts
                for linkedAccount in metadata.accounts {
                    let account = Account(
                        name: linkedAccount.name,
                        accountType: mapAccountType(linkedAccount.type, subtype: linkedAccount.subtype),
                        lastFourDigits: linkedAccount.mask,
                        institutionName: metadata.institutionName
                    )
                    account.isLinked = true
                    account.plaidItemId = itemId
                    account.plaidAccountId = linkedAccount.id
                    account.plaidStatus = .connected
                    
                    modelContext.insert(account)
                }
                
                try modelContext.save()
                
                // Initial sync
                _ = try await PlaidService.shared.syncAllTransactions(modelContext: modelContext)
                
                showingSuccess = true
                
            } catch let plaidError as PlaidError {
                error = plaidError
                showingError = true
            } catch {
                self.error = .networkError(error)
                showingError = true
            }
        }
    }
    
    private func handleLinkExit(_ error: PlaidError?) {
        if let error = error, case .userCancelled = error {
            // User cancelled - no error to show
            return
        }
        
        if let error = error {
            self.error = error
            showingError = true
        }
    }
    
    private func mapAccountType(_ type: String, subtype: String?) -> AccountType {
        switch type {
        case "depository":
            if subtype == "savings" {
                return .savings
            }
            return .checking
        case "credit":
            return .creditCard
        case "investment":
            return .investment
        case "loan":
            return .loan
        default:
            return .other
        }
    }
}

// MARK: - Sync Status View

/// Displays sync status and provides manual sync option
struct PlaidSyncStatusView: View {
    
    @SwiftUI.Environment(\.modelContext) private var modelContext
    
    @State private var isSyncing = false
    @State private var syncProgress: Double = 0.0
    @State private var lastSyncDate: Date?
    @State private var currentError: PlaidError?
    @State private var showingError = false
    @State private var lastResult: PlaidSyncResult?
    
    var body: some View {
        VStack(spacing: 12) {
            // Status Header
            HStack {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                    .symbolEffect(.pulse, isActive: isSyncing)
                    .accessibilityHidden(true)
                
                Text(statusText)
                    .font(.subheadline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if isSyncing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .accessibilityLabel("Syncing")
                } else {
                    Button {
                        sync()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.body)
                    }
                    .disabled(isSyncing)
                    .accessibilityLabel("Sync transactions")
                    .accessibilityHint("Double tap to sync transactions from your bank")
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityValue(statusText)
            
            // Progress Bar (when syncing)
            if isSyncing {
                ProgressView(value: syncProgress)
                    .tint(Color.brandPrimary)
                    .accessibilityLabel("Sync progress")
                    .accessibilityValue("\(Int(syncProgress * 100)) percent complete")
            }
            
            // Last Sync Result
            if let result = lastResult {
                HStack {
                    Text(result.description)
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .alert("Sync Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(currentError?.localizedDescription ?? "Failed to sync")
                .lineLimit(3)
                .minimumScaleFactor(0.7)
        }
        .task {
            loadState()
        }
    }
    
    private var statusIcon: String {
        if isSyncing {
            return "arrow.triangle.2.circlepath"
        } else if currentError != nil {
            return "exclamationmark.triangle.fill"
        } else {
            return "checkmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        if isSyncing {
            return Color.brandPrimary
        } else if currentError != nil {
            return .orange
        } else {
            return .green
        }
    }
    
    private var statusText: String {
        if isSyncing {
            return "Syncing transactions..."
        } else if let error = currentError {
            return error.localizedDescription
        } else if let lastSync = lastSyncDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "Last synced \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
        } else {
            return "Not synced yet"
        }
    }
    
    @MainActor
    private func loadState() {
        let service = PlaidService.shared
        isSyncing = service.isSyncing
        syncProgress = service.syncProgress
        lastSyncDate = service.lastSyncDate
        currentError = service.currentError
    }
    
    private func sync() {
        HapticService.play(.medium)
        AccessibilityAnnouncement.announce("Starting transaction sync")
        
        Task { @MainActor in
            do {
                isSyncing = true
                lastResult = try await PlaidService.shared.syncAllTransactions(modelContext: modelContext)
                loadState()
                HapticService.play(.success)
                if let result = lastResult {
                    AccessibilityAnnouncement.announce("Sync complete. \(result.description)")
                }
            } catch let error as PlaidError {
                currentError = error
                showingError = true
                HapticService.play(.error)
                AccessibilityAnnouncement.announce("Sync failed. \(error.localizedDescription)")
            } catch {
                currentError = .networkError(error)
                showingError = true
                HapticService.play(.error)
                AccessibilityAnnouncement.announce("Sync failed. Network error.")
            }
            isSyncing = false
        }
    }
}

// MARK: - Connected Accounts Card

/// Dashboard card showing connected bank accounts
struct ConnectedAccountsCard: View {
    
    @Query(filter: #Predicate<Account> { $0.isLinked == true })
    private var linkedAccounts: [Account]
    
    @State private var lastSyncDate: Date?
    
    // Computed property to get first 3 accounts as Array
    private var displayedAccounts: [Account] {
        Array(linkedAccounts.prefix(3))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Label("Connected Banks", systemImage: "building.columns.fill")
                    .font(.headline)
                
                Spacer()
                
                if !linkedAccounts.isEmpty {
                    NavigationLink {
                        ConnectedAccountsListView()
                    } label: {
                        Text("Manage")
                            .font(.subheadline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
            
            if linkedAccounts.isEmpty {
                // Empty State
                VStack(spacing: 12) {
                    Image(systemName: "link.badge.plus")
                        .font(.largeTitle)
                        .foregroundStyle(Color.brandPrimary.opacity(0.5))
                        .accessibilityHidden(true)
                    
                    Text("No banks connected")
                        .font(.subheadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                    
                    ConnectBankButton(style: .secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                // Account List
                VStack(spacing: 12) {
                    ForEach(displayedAccounts) { (account: Account) in
                        HStack {
                            Image(systemName: account.plaidStatus.icon)
                                .foregroundStyle(Color(hex: account.plaidStatus.color))
                                .accessibilityHidden(true)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.displayNameWithDigits)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .fontWeight(.medium)
                                
                                Text(account.institutionName ?? "Bank")
                                    .font(.caption)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(account.currentBalance, format: .currency(code: "USD"))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(account.currentBalance >= 0 ? .primary : Color.red)
                        }
                    }
                    
                    if linkedAccounts.count > 3 {
                        Text("+\(linkedAccounts.count - 3) more accounts")
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Sync Status
                if let lastSync = lastSyncDate {
                    HStack {
                        Text("Last synced")
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.tertiary)
                        
                        Text(lastSync, style: .relative)
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.tertiary)
                        
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .task {
            loadSyncDate()
        }
    }
    
    @MainActor
    private func loadSyncDate() {
        lastSyncDate = PlaidService.shared.lastSyncDate
    }
}

// MARK: - Connected Accounts List View

/// Full list view for managing connected accounts
struct ConnectedAccountsListView: View {
    
    @Query(filter: #Predicate<Account> { $0.isLinked == true })
    private var linkedAccounts: [Account]
    
    @SwiftUI.Environment(\.modelContext) private var modelContext
    
    @State private var accountToDisconnect: Account?
    @State private var showingDisconnectAlert = false
    
    var body: some View {
        List {
            // Sync Status Section
            Section {
                PlaidSyncStatusView()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            
            // Accounts Section
            Section("Linked Accounts") {
                ForEach(linkedAccounts) { (account: Account) in
                    AccountRowView(account: account) {
                        accountToDisconnect = account
                        showingDisconnectAlert = true
                    }
                }
                
                // Add Account Button
                ConnectBankButton(style: .secondary)
            }
        }
        .navigationTitle("Connected Banks")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            AccessibilityAnnouncement.screenChanged("Connected banks")
        }
        .alert("Disconnect Account?", isPresented: $showingDisconnectAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Disconnect", role: .destructive) {
                if let account = accountToDisconnect {
                    disconnectAccount(account)
                }
            }
        } message: {
            if let account = accountToDisconnect {
                Text("This will stop syncing transactions for \(account.name). Your existing transactions will be kept.")
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
            }
        }
    }
    
    private func disconnectAccount(_ account: Account) {
        guard let itemId = account.plaidItemId else { return }
        
        Task { @MainActor in
            do {
                try await PlaidService.shared.disconnectItem(itemId: itemId, modelContext: modelContext)
                HapticService.play(.success)
            } catch {
                HapticService.play(.error)
            }
        }
    }
}

// MARK: - Account Row View

private struct AccountRowView: View {
    
    let account: Account
    let onDisconnect: () -> Void
    
    var body: some View {
        HStack {
            // Status Icon
            Image(systemName: account.plaidStatus.icon)
                .font(.title3)
                .foregroundStyle(Color(hex: account.plaidStatus.color))
                .frame(width: 32)
                .accessibilityHidden(true)
            
            // Account Info
            VStack(alignment: .leading, spacing: 4) {
                Text(account.displayNameWithDigits)
                    .font(.body)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    Text(account.institutionName ?? "Bank")
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                    
                    Text("•")
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                    
                    Text(account.plaidStatus.displayName)
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(Color(hex: account.plaidStatus.color))
                }
            }
            
            Spacer()
            
            // Balance
            VStack(alignment: .trailing, spacing: 4) {
                Text(account.currentBalance, format: .currency(code: "USD"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(account.currentBalance >= 0 ? .primary : Color.red)
                
                if let lastSync = account.lastPlaidSync {
                    Text(lastSync, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                // Refresh this account
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .accessibilityLabel("Refresh account balance")
            .accessibilityHint("Double tap to sync latest transactions for this account")
            
            if account.plaidStatus == .needsReauth {
                Button {
                    // Re-authenticate
                } label: {
                    Label("Update Login", systemImage: "person.badge.key")
                }
                .accessibilityLabel("Update login credentials")
                .accessibilityHint("Double tap to re-authenticate with your bank")
            }
            
            Divider()
            
            Button(role: .destructive) {
                onDisconnect()
            } label: {
                Label("Disconnect", systemImage: "link.badge.minus")
            }
            .accessibilityLabel("Disconnect account")
            .accessibilityHint("Double tap to stop syncing this account")
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct ConnectBankButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ConnectBankButton(style: .prominent)
            ConnectBankButton(style: .secondary)
            ConnectBankButton(style: .minimal)
        }
        .padding()
        .modelContainer(ModelContainer.preview())
    }
}

struct PlaidSyncStatusView_Previews: PreviewProvider {
    static var previews: some View {
        PlaidSyncStatusView()
            .padding()
            .modelContainer(ModelContainer.preview())
    }
}

struct ConnectedAccountsCard_Previews: PreviewProvider {
    static var previews: some View {
        ConnectedAccountsCard()
            .padding()
            .modelContainer(ModelContainer.preview())
    }
}
#endif
