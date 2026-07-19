//  PlaidService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.4 - Credit card balance fix
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE:
//  Core service for Plaid integration handling:
//  - Link token creation and public token exchange
//  - Transaction synchronization with incremental sync
//  - Account balance updates
//  - Keychain-based credential storage
//  - Subscription tier enforcement (Pro required)
//
//  CHANGES v1.4:
//  - Credit cards/loans now show 'current' balance (amount owed) instead of 'available' (remaining credit)
//  - Depository accounts continue using 'available' (spendable amount)
//
//  CHANGES v1.3:
//  - Added Authorization header with Supabase anon key to all requests
//  - Fixed 401 unauthorized errors when calling Edge Functions
//
//  CHANGES v1.2:
//  - Updated all endpoint paths to match Supabase Edge Function naming
//  - /api/plaid/* paths changed to /plaid-* paths
//
//  CHANGES v1.1:
//  - Fixed predicate syntax (removed global function usage)
//  - Removed Transaction.fromPlaid extension (already in Transaction.swift)
//  - Removed hasPlaidModifications extension (already in Transaction.swift)
//  - Fixed urlSession initialization

import Foundation
import SwiftData
import Security

// MARK: - Plaid Service

@MainActor
final class PlaidService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = PlaidService()
    private init() {
        self.urlSession = PlaidService.createURLSession()
        loadStoredItemIds()
    }
    
    // MARK: - Published State
    
    /// Whether Link is currently being presented
    @Published var isLinking = false
    
    /// Whether a sync operation is in progress
    @Published var isSyncing = false
    
    /// Current sync progress (0.0 - 1.0)
    @Published var syncProgress: Double = 0.0
    
    /// Last successful sync date
    @Published var lastSyncDate: Date?
    
    /// Current error state
    @Published var currentError: PlaidError?
    
    /// Connected item IDs (for tracking connections)
    @Published private(set) var connectedItemIds: Set<String> = []
    
    // MARK: - Dependencies
    
    private let subscriptionManager = SubscriptionManager.shared
    private let urlSession: URLSession
    
    // MARK: - Configuration
    
    /// Maximum accounts allowed per user
    private let maxConnectedAccounts = 5
    
    /// Batch size for transaction sync
    private let syncBatchSize = 500
    
    /// Retry configuration
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 2.0
    
    // MARK: - URL Session Setup
    
    private static func createURLSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }
    
    // MARK: - Subscription Check
    
    /// Checks if user has Pro subscription required for Plaid
    func checkSubscription() throws {
        guard subscriptionManager.currentTier == .pro else {
            throw PlaidError.subscriptionRequired
        }
    }
    
    // MARK: - Link Token Creation
    
    /// Creates a Link token to initialize Plaid Link
    /// - Parameter existingAccessToken: Pass existing token for update mode
    /// - Returns: Link token string for PlaidLinkView
    func createLinkToken(existingAccessToken: String? = nil) async throws -> String {
        try checkSubscription()
        
        isLinking = true
        defer { isLinking = false }
        
        let userId = getUserIdentifier()
        
        let request = CreateLinkTokenRequest(
            userId: userId,
            clientName: PlaidConfiguration.clientName,
            products: PlaidConfiguration.products.map { $0.rawValue },
            countryCodes: PlaidConfiguration.countryCodes,
            language: PlaidConfiguration.language,
            webhook: PlaidConfiguration.webhookURL,
            redirectUri: PlaidConfiguration.redirectURI,
            accessToken: existingAccessToken
        )
        
        let response: LinkTokenResponse = try await postToBackend(
            endpoint: "/plaid-create-link-token",
            body: request
        )
        
        return response.linkToken
    }
    
    // MARK: - Public Token Exchange
    
    /// Exchanges a public token (from Link success) for an access token
    /// - Parameters:
    ///   - publicToken: Token received from Plaid Link
    ///   - metadata: Metadata from Link including institution info
    /// - Returns: Item ID for the new connection
    func exchangePublicToken(_ publicToken: String, metadata: LinkMetadata) async throws -> String {
        try checkSubscription()
        
        // Check account limit
        if connectedItemIds.count >= maxConnectedAccounts {
            throw PlaidError.accountLimitReached(max: maxConnectedAccounts)
        }
        
        let request = ExchangeTokenRequest(publicToken: publicToken)
        
        let response: TokenExchangeResponse = try await postToBackend(
            endpoint: "/plaid-exchange-token",
            body: request
        )
        
        // Store credentials in Keychain
        // Note: In production, access tokens should stay on your backend
        // Only store item_id on device for reference
        try storeInKeychain(
            key: PlaidKeychainKey.itemIdPrefix + response.itemId,
            value: response.itemId
        )
        
        // Track connection
        connectedItemIds.insert(response.itemId)
        saveStoredItemIds()

        return response.itemId
    }

    // MARK: - Account Creation

    /// Creates FLO Account records for the accounts linked in a successful
    /// Link session. Shared by every link-success path so account setup
    /// (Plaid IDs, status, type mapping) can't drift between callers.
    @discardableResult
    func createAccounts(
        from metadata: LinkMetadata,
        itemId: String,
        modelContext: ModelContext
    ) throws -> [Account] {
        var created: [Account] = []

        for linkedAccount in metadata.accounts {
            let account = Account(
                name: linkedAccount.name,
                accountType: Self.mapAccountType(linkedAccount.type, subtype: linkedAccount.subtype),
                lastFourDigits: linkedAccount.mask,
                institutionName: metadata.institutionName
            )
            account.isLinked = true
            account.plaidItemId = itemId
            account.plaidAccountId = linkedAccount.id
            account.plaidStatus = .connected

            modelContext.insert(account)
            created.append(account)
        }

        try modelContext.save()
        return created
    }

    /// Maps Plaid account type strings to FLO AccountType
    static func mapAccountType(_ type: String, subtype: String?) -> AccountType {
        switch type {
        case "depository":
            return subtype == "savings" ? .savings : .checking
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

    // MARK: - Transaction Sync
    
    /// Syncs transactions for all connected accounts
    /// - Parameter modelContext: SwiftData context for persistence
    /// - Returns: Aggregate sync result
    func syncAllTransactions(modelContext: ModelContext) async throws -> PlaidSyncResult {
        try checkSubscription()
        
        guard !isSyncing else {
            throw PlaidError.transactionSyncFailed("Sync already in progress")
        }
        
        isSyncing = true
        syncProgress = 0.0
        currentError = nil
        
        defer {
            isSyncing = false
            syncProgress = 1.0
        }
        
        var totalAdded = 0
        var totalUpdated = 0
        var totalRemoved = 0
        var totalSkipped = 0
        var lastCursor = ""
        
        // Get all linked accounts
        let linkedAccounts = try await fetchLinkedAccounts(modelContext: modelContext)
        let totalAccounts = linkedAccounts.count
        
        for (index, account) in linkedAccounts.enumerated() {
            guard let itemId = account.plaidItemId else { continue }
            
            do {
                let result = try await syncTransactionsForItem(
                    itemId: itemId,
                    accountId: account.id,
                    modelContext: modelContext
                )
                
                totalAdded += result.added
                totalUpdated += result.updated
                totalRemoved += result.removed
                totalSkipped += result.skipped
                lastCursor = result.cursor
                
                // Update account sync status
                account.lastPlaidSync = Date()
                account.plaidStatus = .connected
                
            } catch let error as PlaidError {
                // Handle specific errors
                if error.requiresReconnection {
                    account.plaidStatus = .needsReauth
                } else {
                    account.plaidStatus = .error
                }
                // Continue with other accounts
                print("⚠️ Sync error for account \(account.name): \(error.localizedDescription)")
            }
            
            // Update progress
            syncProgress = Double(index + 1) / Double(totalAccounts)
        }
        
        // Save all changes
        try modelContext.save()
        
        lastSyncDate = Date()
        
        return PlaidSyncResult(
            added: totalAdded,
            updated: totalUpdated,
            removed: totalRemoved,
            skipped: totalSkipped,
            cursor: lastCursor,
            hasMore: false
        )
    }
    
    /// Syncs transactions for a specific Plaid item
    private func syncTransactionsForItem(
        itemId: String,
        accountId: UUID,
        modelContext: ModelContext
    ) async throws -> PlaidSyncResult {
        
        // Get stored cursor for incremental sync
        let cursor = getFromKeychain(key: PlaidKeychainKey.cursor(for: itemId))
        
        var totalAdded = 0
        var totalUpdated = 0
        var totalRemoved = 0
        var totalSkipped = 0
        var currentCursor = cursor
        var hasMore = true
        
        while hasMore {
            let request = TransactionsSyncRequest(
                cursor: currentCursor,
                count: syncBatchSize
            )
            
            let response: TransactionsSyncResponse = try await postToBackend(
                endpoint: "/plaid-transactions",
                body: request,
                itemId: itemId
            )
            
            // Process added transactions
            for plaidTx in response.added {
                let result = try await processTransaction(
                    plaidTx,
                    accountId: accountId,
                    modelContext: modelContext,
                    isUpdate: false
                )
                if result { totalAdded += 1 } else { totalSkipped += 1 }
            }
            
            // Process modified transactions
            for plaidTx in response.modified {
                let result = try await processTransaction(
                    plaidTx,
                    accountId: accountId,
                    modelContext: modelContext,
                    isUpdate: true
                )
                if result { totalUpdated += 1 } else { totalSkipped += 1 }
            }
            
            // Process removed transactions
            for removed in response.removed {
                let wasRemoved = try await removeTransaction(
                    plaidTransactionId: removed.transactionId,
                    modelContext: modelContext
                )
                if wasRemoved { totalRemoved += 1 }
            }
            
            currentCursor = response.nextCursor
            hasMore = response.hasMore
        }
        
        // Store new cursor
        if let finalCursor = currentCursor {
            try? storeInKeychain(
                key: PlaidKeychainKey.cursor(for: itemId),
                value: finalCursor
            )
        }
        
        return PlaidSyncResult(
            added: totalAdded,
            updated: totalUpdated,
            removed: totalRemoved,
            skipped: totalSkipped,
            cursor: currentCursor ?? "",
            hasMore: false
        )
    }
    
    // MARK: - Transaction Processing
    
    /// Processes a single Plaid transaction
    private func processTransaction(
        _ plaidTx: PlaidTransaction,
        accountId: UUID,
        modelContext: ModelContext,
        isUpdate: Bool
    ) async throws -> Bool {
        
        // Check for existing transaction by Plaid ID
        if let existing = try await findTransaction(
            byPlaidId: plaidTx.transactionId,
            modelContext: modelContext
        ) {
            if isUpdate {
                // Update existing transaction if not user-modified
                if !existing.hasPlaidModifications {
                    existing.amount = plaidTx.absoluteAmount
                    existing.date = plaidTx.date
                    existing.merchantName = plaidTx.displayName
                    existing.plaidPending = plaidTx.pending
                    existing.plaidLastSync = Date()
                    existing.plaidCategoryHierarchy = plaidTx.categoryString
                    return true
                }
            }
            // Skip if already exists or user modified
            return false
        }
        
        // Check for potential duplicate (fuzzy match)
        if try await checkForDuplicate(plaidTx, modelContext: modelContext) {
            return false
        }
        
        // Fetch the linked account
        let fetchDescriptor = FetchDescriptor<Account>(
            predicate: #Predicate { $0.id == accountId }
        )
        guard let account = try? modelContext.fetch(fetchDescriptor).first else {
            return false
        }
        
        // Create new transaction using the existing factory method in Transaction.swift
        let transaction = Transaction.fromPlaid(
            plaidTransactionId: plaidTx.transactionId,
            plaidAccountId: plaidTx.accountId,
            amount: plaidTx.amount,
            date: plaidTx.date,
            merchantName: plaidTx.displayName,
            pending: plaidTx.pending,
            categoryHierarchy: plaidTx.category,
            account: account
        )
        
        // Try to auto-categorize based on Plaid category
        if let category = await mapPlaidCategory(plaidTx.personalFinanceCategory, modelContext: modelContext) {
            transaction.category = category
        }
        
        modelContext.insert(transaction)
        return true
    }
    
    /// Finds a transaction by Plaid ID
    private func findTransaction(
        byPlaidId plaidId: String,
        modelContext: ModelContext
    ) async throws -> Transaction? {
        let fetchDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.plaidTransactionId == plaidId }
        )
        return try modelContext.fetch(fetchDescriptor).first
    }
    
    /// Removes a transaction by Plaid ID
    private func removeTransaction(
        plaidTransactionId: String,
        modelContext: ModelContext
    ) async throws -> Bool {
        guard let transaction = try await findTransaction(
            byPlaidId: plaidTransactionId,
            modelContext: modelContext
        ) else {
            return false
        }
        
        modelContext.delete(transaction)
        return true
    }
    
    /// Checks for potential duplicate transactions
    private func checkForDuplicate(
        _ plaidTx: PlaidTransaction,
        modelContext: ModelContext
    ) async throws -> Bool {
        // Look for manual transactions with same amount and date
        let amount = plaidTx.absoluteAmount
        let date = plaidTx.date
        let tolerance: TimeInterval = 86400 // 1 day
        
        let minDate = date.addingTimeInterval(-tolerance)
        let maxDate = date.addingTimeInterval(tolerance)
        
        // Find transactions without Plaid ID in the date range
        let fetchDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { tx in
                tx.plaidTransactionId == nil &&
                tx.date >= minDate &&
                tx.date <= maxDate
            }
        )
        
        let candidates = try modelContext.fetch(fetchDescriptor)
        
        // Check amount match
        for candidate in candidates {
            if abs(candidate.amount - amount) < 0.01 {
                // Found a matching manual transaction, link it to Plaid
                candidate.plaidTransactionId = plaidTx.transactionId
                candidate.plaidAccountId = plaidTx.accountId
                candidate.importSource = .plaid
                candidate.plaidOriginalMerchant = plaidTx.displayName
                candidate.plaidLastSync = Date()
                return true // Treated as duplicate (now linked)
            }
        }
        
        return false
    }
    
    // MARK: - Category Mapping
    
    /// Maps Plaid category to FLO category
    private func mapPlaidCategory(
        _ plaidCategory: PlaidPersonalFinanceCategory?,
        modelContext: ModelContext
    ) async -> Category? {
        guard let plaidCategory = plaidCategory else { return nil }
        
        // Map Plaid primary categories to FLO categories
        let categoryMapping: [String: String] = [
            "INCOME": "Income",
            "TRANSFER_IN": "Income",
            "TRANSFER_OUT": "Transfer",
            "LOAN_PAYMENTS": "Debt Payment",
            "BANK_FEES": "Bank Fees",
            "ENTERTAINMENT": "Entertainment",
            "FOOD_AND_DRINK": "Food & Dining",
            "GENERAL_MERCHANDISE": "Shopping",
            "HOME_IMPROVEMENT": "Home",
            "MEDICAL": "Healthcare",
            "PERSONAL_CARE": "Personal Care",
            "GENERAL_SERVICES": "Services",
            "GOVERNMENT_AND_NON_PROFIT": "Government",
            "TRANSPORTATION": "Transportation",
            "TRAVEL": "Travel",
            "RENT_AND_UTILITIES": "Utilities"
        ]
        
        let floCategory = categoryMapping[plaidCategory.primary] ?? "Other"
        
        // Find or return nil (let user categorize)
        let fetchDescriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.name == floCategory }
        )
        return try? modelContext.fetch(fetchDescriptor).first
    }
    
    // MARK: - Account Operations
    
    /// Fetches all linked accounts from SwiftData
    private func fetchLinkedAccounts(modelContext: ModelContext) async throws -> [Account] {
        let fetchDescriptor = FetchDescriptor<Account>(
            predicate: #Predicate { $0.isLinked == true }
        )
        return try modelContext.fetch(fetchDescriptor)
    }
    
    /// Updates account balances from Plaid
    /// One backend request per Plaid item (linked bank) — accounts from the
    /// same institution share an itemId and arrive in the same response.
    func updateAccountBalances(modelContext: ModelContext) async throws {
        try checkSubscription()

        let linkedAccounts = try await fetchLinkedAccounts(modelContext: modelContext)
        let accountsByItem = Dictionary(
            grouping: linkedAccounts.filter { $0.plaidItemId != nil },
            by: { $0.plaidItemId! }
        )

        for (itemId, accounts) in accountsByItem {
            do {
                let response: AccountsResponse = try await getFromBackend(
                    endpoint: "/plaid-accounts",
                    itemId: itemId
                )

                for account in accounts {
                    guard let plaidAccount = response.accounts.first(where: { $0.accountId == account.plaidAccountId }) else {
                        continue
                    }
                    // Credit cards & loans: use 'current' (amount owed)
                    // Depository (checking/savings): use 'available' (spendable amount)
                    if plaidAccount.type == .credit || plaidAccount.type == .loan {
                        account.currentBalance = plaidAccount.balances.current ?? 0.0
                    } else {
                        account.currentBalance = plaidAccount.balances.effectiveBalance
                    }
                    account.lastBalanceUpdate = Date()

                    // Update credit limit if credit card
                    if account.accountType == .creditCard, let limit = plaidAccount.balances.limit {
                        account.creditLimit = limit
                    }
                }

            } catch {
                print("⚠️ Failed to update balances for item \(itemId): \(error)")
            }
        }

        try modelContext.save()
    }
    
    /// Disconnects a bank connection
    func disconnectItem(itemId: String, modelContext: ModelContext) async throws {
        // Call backend to remove item
        try await deleteFromBackend(
            endpoint: "/plaid-disconnect",
            itemId: itemId
        )
        
        // Update local accounts
        let fetchDescriptor = FetchDescriptor<Account>(
            predicate: #Predicate { $0.plaidItemId == itemId }
        )
        let accounts = try modelContext.fetch(fetchDescriptor)
        
        for account in accounts {
            account.isLinked = false
            account.plaidStatus = .notConnected
            account.plaidItemId = nil
            account.plaidAccountId = nil
            account.lastPlaidSync = nil
        }
        
        // Remove from tracking
        connectedItemIds.remove(itemId)
        saveStoredItemIds()
        
        // Clear Keychain entries
        deleteFromKeychain(key: PlaidKeychainKey.itemIdPrefix + itemId)
        deleteFromKeychain(key: PlaidKeychainKey.cursor(for: itemId))
        
        try modelContext.save()
    }
    
    // MARK: - Network Helpers
    
    /// POST request to backend
    private func postToBackend<Request: Encodable, Response: Decodable>(
        endpoint: String,
        body: Request,
        itemId: String? = nil
    ) async throws -> Response {
        let url = URL(string: PlaidConfiguration.backendBaseURL + endpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(PlaidConfiguration.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(getUserIdentifier(), forHTTPHeaderField: "X-User-ID")
        
        if let itemId = itemId {
            request.setValue(itemId, forHTTPHeaderField: "X-Plaid-Item-ID")
        }
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)
        
        return try await executeRequest(request)
    }
    
    /// GET request to backend
    private func getFromBackend<Response: Decodable>(
        endpoint: String,
        itemId: String? = nil
    ) async throws -> Response {
        let url = URL(string: PlaidConfiguration.backendBaseURL + endpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(PlaidConfiguration.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(getUserIdentifier(), forHTTPHeaderField: "X-User-ID")
        
        if let itemId = itemId {
            request.setValue(itemId, forHTTPHeaderField: "X-Plaid-Item-ID")
        }
        
        return try await executeRequest(request)
    }
    
    /// DELETE request to backend
    private func deleteFromBackend(
        endpoint: String,
        itemId: String
    ) async throws {
        let url = URL(string: PlaidConfiguration.backendBaseURL + endpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(PlaidConfiguration.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(getUserIdentifier(), forHTTPHeaderField: "X-User-ID")
        request.setValue(itemId, forHTTPHeaderField: "X-Plaid-Item-ID")
        
        let (_, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw PlaidError.serverError(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0,
                message: "Failed to delete item"
            )
        }
    }
    
    /// Executes request with retry logic
    private func executeRequest<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                let (data, response) = try await urlSession.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw PlaidError.invalidResponse
                }
                
                // DEBUG: Log raw response
                #if DEBUG
                if let rawString = String(data: data, encoding: .utf8) {
                    print("🔍 Plaid API Response [\(request.url?.lastPathComponent ?? "unknown")]:")
                    print("   Status: \(httpResponse.statusCode)")
                    print("   Body: \(rawString.prefix(500))")
                }
                #endif
                
                // Handle error status codes
                if !(200...299).contains(httpResponse.statusCode) {
                    // Try to parse error response
                    if let errorResponse = try? JSONDecoder.plaidDecoder.decode(BackendError.self, from: data) {
                        throw mapBackendError(errorResponse, statusCode: httpResponse.statusCode)
                    }
                    throw PlaidError.serverError(
                        statusCode: httpResponse.statusCode,
                        message: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                    )
                }
                
                // Decode success response
                do {
                    return try JSONDecoder.plaidDecoder.decode(Response.self, from: data)
                } catch {
                    #if DEBUG
                    print("❌ Plaid decoding error: \(error)")
                    print("   Expected type: \(Response.self)")
                    #endif
                    throw error
                }
                
            } catch let error as PlaidError where error.isRetryable {
                lastError = error
                if attempt < maxRetries {
                    try await Task.sleep(nanoseconds: UInt64(retryDelay * Double(attempt) * 1_000_000_000))
                }
            } catch {
                throw error
            }
        }
        
        throw lastError ?? PlaidError.networkError(NSError(domain: "PlaidService", code: -1))
    }
    
    /// Maps backend error to PlaidError
    private func mapBackendError(_ error: BackendError, statusCode: Int) -> PlaidError {
        switch error.code {
        case "SUBSCRIPTION_REQUIRED":
            return .subscriptionRequired
        case "ITEM_LOGIN_REQUIRED":
            return .needsReauthentication(error.message)
        case "RATE_LIMIT_EXCEEDED":
            return .rateLimitExceeded
        case "ITEM_NOT_FOUND":
            return .itemNotFound
        default:
            return .backendError(error.message)
        }
    }
    
    // MARK: - Keychain Helpers
    
    private func storeInKeychain(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw PlaidError.networkError(NSError(domain: "Keychain", code: -1))
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.finchandpoppy.flo.plaid",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing
        SecItemDelete(query as CFDictionary)
        
        // Add new
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw PlaidError.networkError(NSError(domain: "Keychain", code: Int(status)))
        }
    }
    
    private func getFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.finchandpoppy.flo.plaid",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return value
    }
    
    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.finchandpoppy.flo.plaid"
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - User Identifier
    
    private func getUserIdentifier() -> String {
        let key = "com.finchandpoppy.flo.userId"
        
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }
    
    // MARK: - Item ID Persistence
    
    private func loadStoredItemIds() {
        if let stored = UserDefaults.standard.stringArray(forKey: "plaid.connectedItemIds") {
            connectedItemIds = Set(stored)
        }
    }
    
    private func saveStoredItemIds() {
        UserDefaults.standard.set(Array(connectedItemIds), forKey: "plaid.connectedItemIds")
    }
}

// MARK: - Supporting Types

/// Backend error response structure
private struct BackendError: Decodable {
    let code: String
    let message: String
}

/// Metadata passed from Plaid Link on success
struct LinkMetadata: Sendable {
    let publicToken: String
    let institutionId: String?
    let institutionName: String?
    let accounts: [LinkAccount]
}

/// Account info from Link
struct LinkAccount: Sendable {
    let id: String
    let name: String
    let mask: String?
    let type: String
    let subtype: String?
}

// MARK: - Preview Support

#if DEBUG
extension PlaidService {
    /// Creates mock sync result for previews
    static func mockSyncResult() -> PlaidSyncResult {
        PlaidSyncResult(
            added: 15,
            updated: 3,
            removed: 1,
            skipped: 2,
            cursor: "mock-cursor-123",
            hasMore: false
        )
    }
}
#endif
