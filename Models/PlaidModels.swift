//  PlaidModels.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.2 - Added Supabase anon key configuration
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.2:
//  - Added supabaseAnonKey to PlaidConfiguration
//  - Sandbox and Production keys for API authorization
//
//  CHANGES v1.1:
//  - Updated backendBaseURL to point to Supabase Edge Functions
//  - Sandbox: fdlttnbwswnlrmnfdulz.supabase.co
//  - Production: bhpdiujgnqxsfwnorufa.supabase.co
//  - Updated webhookURL to match Supabase deployment
//
//  PURPOSE:
//  Defines all Plaid-related models including configuration, error types,
//  API response models, and data transfer objects for bank integration.
//
//  ARCHITECTURE:
//  - PlaidConfiguration: Environment and credential management
//  - PlaidError: Comprehensive error handling with user-friendly messages
//  - Response Models: Strongly-typed API responses from Plaid
//  - DTO Models: Data transfer objects for internal use
//
//  SECURITY NOTES:
//  - NEVER expose Plaid credentials in the iOS app
//  - All API calls MUST go through your backend server
//  - Access tokens stored in Keychain (see PlaidService)

import Foundation

// MARK: - Plaid Configuration

/// Configuration for Plaid integration
/// All sensitive values should be loaded from your backend, not hardcoded
struct PlaidConfiguration {
    
    /// Display name shown in Plaid Link
    static let clientName = "FLO"
    
    /// Plaid environment
    /// - .sandbox: For development and testing
    /// - .development: Limited production data for development
    /// - .production: Live production environment
    static var environment: PlaidEnvironment {
        #if DEBUG
        return .sandbox
        #else
        return .production
        #endif
    }
    
    /// Products to request access to
    /// Transactions is primary; others can be added as needed
    static let products: [PlaidProduct] = [.transactions]
    
    /// Supported country codes
    static let countryCodes: [String] = ["US"]
    
    /// Language for Plaid Link UI
    static let language = "en"
    
    /// Base URL for YOUR backend API (Supabase Edge Functions)
    /// CRITICAL: These URLs point to your deployed Supabase Edge Functions
    static var backendBaseURL: String {
        #if DEBUG
        // Sandbox project for development/testing
        return "https://fdlttnbwswnlrmnfdulz.supabase.co/functions/v1"
        #else
        // Production project for App Store release
        return "https://bhpdiujgnqxsfwnorufa.supabase.co/functions/v1"
        #endif
    }
    
    /// Webhook URL for Plaid to notify of updates
    /// Configured in Plaid Dashboard
    static var webhookURL: String {
        #if DEBUG
        return "https://fdlttnbwswnlrmnfdulz.supabase.co/functions/v1/plaid-webhook"
        #else
        return "https://bhpdiujgnqxsfwnorufa.supabase.co/functions/v1/plaid-webhook"
        #endif
    }
    
    /// Redirect URI for OAuth flows (required for some institutions)
    static let redirectURI = "flo://plaid-oauth"
    
    /// Supabase anon key for API authorization
    /// These are PUBLIC keys - safe to include in the app
    static var supabaseAnonKey: String {
        #if DEBUG
        // Sandbox project anon key
        return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZkbHR0bmJ3c3dubHJtbmZkdWx6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkxMTAzODUsImV4cCI6MjA4NDY4NjM4NX0.QlKLqi1KpzqwvV3WMlEb7INgi58PE44MjZNVDaEWEMA"
        #else
        // Production project anon key - UPDATE THIS with your production anon key
        return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJocGRpdWpnbnF4c2Z3bm9ydWZhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkxMTI2MjAsImV4cCI6MjA4NDY4ODYyMH0.WymXYIwTEuuz9lMwyckFpHhB-5tYbMj1OyPp69_IqzU"
        #endif
    }
}

// MARK: - Plaid Environment

/// Plaid API environments
enum PlaidEnvironment: String, Codable, Sendable {
    case sandbox = "sandbox"
    case development = "development"
    case production = "production"
    
    /// Base URL for Plaid API (used by backend only)
    var baseURL: String {
        switch self {
        case .sandbox:
            return "https://sandbox.plaid.com"
        case .development:
            return "https://development.plaid.com"
        case .production:
            return "https://production.plaid.com"
        }
    }
}

// MARK: - Plaid Products

/// Plaid products that can be requested
enum PlaidProduct: String, Codable, Sendable, CaseIterable {
    case transactions = "transactions"
    case auth = "auth"
    case identity = "identity"
    case assets = "assets"
    case investments = "investments"
    case liabilities = "liabilities"
    case paymentInitiation = "payment_initiation"
    case incomeVerification = "income_verification"
    case transfer = "transfer"
    case signal = "signal"
    
    var displayName: String {
        switch self {
        case .transactions: return "Transactions"
        case .auth: return "Account Numbers"
        case .identity: return "Identity Verification"
        case .assets: return "Assets"
        case .investments: return "Investments"
        case .liabilities: return "Liabilities"
        case .paymentInitiation: return "Payments"
        case .incomeVerification: return "Income Verification"
        case .transfer: return "Transfers"
        case .signal: return "Signal"
        }
    }
}

// MARK: - Plaid Errors

/// Comprehensive error types for Plaid integration
enum PlaidError: LocalizedError, Sendable {
    // Connection errors
    case linkTokenCreationFailed(String)
    case publicTokenExchangeFailed(String)
    case institutionNotSupported
    case userCancelled
    
    // Sync errors
    case transactionSyncFailed(String)
    case accountSyncFailed(String)
    case cursorExpired
    case rateLimitExceeded
    
    // Account errors
    case accountNotFound
    case accountDisconnected
    case itemNotFound
    
    // Authentication errors
    case notAuthenticated
    case accessTokenExpired
    case needsReauthentication(String)
    
    // Network errors
    case networkError(Error)
    case serverError(statusCode: Int, message: String)
    case invalidResponse
    case decodingError(String)
    
    // Business logic errors
    case subscriptionRequired
    case duplicateAccount
    case accountLimitReached(max: Int)
    
    // Backend errors
    case backendUnavailable
    case backendError(String)
    
    var errorDescription: String? {
        switch self {
        case .linkTokenCreationFailed(let message):
            return "Failed to start bank connection: \(message)"
        case .publicTokenExchangeFailed(let message):
            return "Failed to complete connection: \(message)"
        case .institutionNotSupported:
            return "This financial institution is not currently supported"
        case .userCancelled:
            return "Bank connection was cancelled"
            
        case .transactionSyncFailed(let message):
            return "Failed to sync transactions: \(message)"
        case .accountSyncFailed(let message):
            return "Failed to sync accounts: \(message)"
        case .cursorExpired:
            return "Sync data expired. Please perform a full refresh."
        case .rateLimitExceeded:
            return "Too many requests. Please try again in a few minutes."
            
        case .accountNotFound:
            return "Account not found"
        case .accountDisconnected:
            return "Bank connection has been disconnected"
        case .itemNotFound:
            return "Bank connection not found"
            
        case .notAuthenticated:
            return "Please connect your bank account"
        case .accessTokenExpired:
            return "Bank connection has expired"
        case .needsReauthentication(let institution):
            return "\(institution) requires you to re-authenticate"
            
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message)"
        case .invalidResponse:
            return "Received an invalid response from the server"
        case .decodingError(let message):
            return "Failed to process response: \(message)"
            
        case .subscriptionRequired:
            return "Pro subscription required for bank sync"
        case .duplicateAccount:
            return "This account is already connected"
        case .accountLimitReached(let max):
            return "Maximum of \(max) connected accounts reached"
            
        case .backendUnavailable:
            return "Service temporarily unavailable. Please try again later."
        case .backendError(let message):
            return "Service error: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .linkTokenCreationFailed, .publicTokenExchangeFailed:
            return "Please try connecting again. If the problem persists, contact support."
        case .institutionNotSupported:
            return "Try connecting a different bank or manually enter transactions."
        case .userCancelled:
            return "Tap 'Connect Bank' when you're ready to link your account."
            
        case .transactionSyncFailed, .accountSyncFailed:
            return "Pull down to refresh, or try again later."
        case .cursorExpired:
            return "Your transaction history will be re-downloaded."
        case .rateLimitExceeded:
            return "Wait a few minutes before syncing again."
            
        case .accountNotFound, .itemNotFound:
            return "Please reconnect your bank account."
        case .accountDisconnected:
            return "Tap to reconnect your bank."
            
        case .notAuthenticated, .accessTokenExpired:
            return "Go to Settings > Connected Accounts to reconnect."
        case .needsReauthentication:
            return "Tap to update your login credentials."
            
        case .networkError:
            return "Check your internet connection and try again."
        case .serverError, .invalidResponse, .decodingError:
            return "If this continues, please contact support."
            
        case .subscriptionRequired:
            return "Upgrade to Pro to connect your bank accounts."
        case .duplicateAccount:
            return "This account is already syncing transactions."
        case .accountLimitReached:
            return "Remove an existing connection to add a new one."
            
        case .backendUnavailable, .backendError:
            return "Please try again in a few minutes."
        }
    }
    
    /// Whether the user should be prompted to reconnect
    var requiresReconnection: Bool {
        switch self {
        case .accessTokenExpired, .needsReauthentication, .accountDisconnected:
            return true
        default:
            return false
        }
    }

    /// True when the failure is on FLO's side — network down, backend
    /// unreachable (e.g. paused Supabase project), rate limits — rather than
    /// a problem with the user's bank link. The bank connection itself is
    /// fine, so its status should NOT be flipped to error for these.
    var isTransientInfrastructureError: Bool {
        switch self {
        case .networkError, .serverError, .backendUnavailable, .backendError,
             .rateLimitExceeded, .invalidResponse, .decodingError:
            return true
        default:
            return false
        }
    }
    
    /// Whether this error should trigger a sync retry
    var isRetryable: Bool {
        switch self {
        case .networkError, .serverError, .rateLimitExceeded, .backendUnavailable:
            return true
        default:
            return false
        }
    }
}

// MARK: - API Response Models

/// Response from link token creation endpoint
struct LinkTokenResponse: Codable, Sendable {
    let linkToken: String
    let expiration: Date
    let requestId: String?
    
    enum CodingKeys: String, CodingKey {
        case linkToken = "link_token"
        case expiration
        case requestId = "request_id"
    }
}

/// Response from public token exchange endpoint
struct TokenExchangeResponse: Codable, Sendable {
    let accessToken: String?  // Optional - backend keeps this secure, only item_id needed
    let itemId: String
    let requestId: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case itemId = "item_id"
        case requestId = "request_id"
    }
}

/// Response from accounts endpoint
struct AccountsResponse: Codable, Sendable {
    let accounts: [PlaidAccount]
    let item: PlaidItem
    let requestId: String?
    
    enum CodingKeys: String, CodingKey {
        case accounts
        case item
        case requestId = "request_id"
    }
}

/// Response from transactions sync endpoint
struct TransactionsSyncResponse: Codable, Sendable {
    let added: [PlaidTransaction]
    let modified: [PlaidTransaction]
    let removed: [RemovedTransaction]
    let nextCursor: String
    let hasMore: Bool
    let requestId: String?
    
    enum CodingKeys: String, CodingKey {
        case added
        case modified
        case removed
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
        case requestId = "request_id"
    }
}

/// Removed transaction reference
struct RemovedTransaction: Codable, Sendable {
    let transactionId: String
    
    enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
    }
}

/// Response from item get endpoint
struct ItemResponse: Codable, Sendable {
    let item: PlaidItem
    let status: ItemStatus?
    let requestId: String?
    
    enum CodingKeys: String, CodingKey {
        case item
        case status
        case requestId = "request_id"
    }
}

/// Item status information
struct ItemStatus: Codable, Sendable {
    let transactions: TransactionsStatus?
    let lastWebhook: WebhookStatus?
    
    enum CodingKeys: String, CodingKey {
        case transactions
        case lastWebhook = "last_webhook"
    }
}

/// Transaction sync status
struct TransactionsStatus: Codable, Sendable {
    let lastSuccessfulUpdate: Date?
    let lastFailedUpdate: Date?
    
    enum CodingKeys: String, CodingKey {
        case lastSuccessfulUpdate = "last_successful_update"
        case lastFailedUpdate = "last_failed_update"
    }
}

/// Webhook status
struct WebhookStatus: Codable, Sendable {
    let sentAt: Date?
    let codeSent: String?
    
    enum CodingKeys: String, CodingKey {
        case sentAt = "sent_at"
        case codeSent = "code_sent"
    }
}

// MARK: - Plaid Account Model

/// Represents a bank account from Plaid
struct PlaidAccount: Codable, Identifiable, Sendable {
    let accountId: String
    let balances: PlaidBalances
    let mask: String?
    let name: String
    let officialName: String?
    let type: PlaidAccountType
    let subtype: String?
    let verificationStatus: String?
    
    var id: String { accountId }
    
    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case balances
        case mask
        case name
        case officialName = "official_name"
        case type
        case subtype
        case verificationStatus = "verification_status"
    }
    
    /// Display name combining official name and mask
    var displayName: String {
        let baseName = officialName ?? name
        if let mask = mask {
            return "\(baseName)  — — — —\(mask)"
        }
        return baseName
    }
    
    /// Maps to FLO AccountType
    var floAccountType: AccountType {
        switch type {
        case .depository:
            if subtype == "savings" {
                return .savings
            }
            return .checking
        case .credit:
            return .creditCard
        case .investment:
            return .investment
        case .loan:
            return .loan
        case .brokerage:
            return .investment
        case .other:
            return .other
        }
    }
}

/// Plaid account type
enum PlaidAccountType: String, Codable, Sendable {
    case depository
    case credit
    case loan
    case investment
    case brokerage
    case other
}

/// Account balance information
struct PlaidBalances: Codable, Sendable {
    let available: Double?
    let current: Double?
    let limit: Double?
    let isoCurrencyCode: String?
    let unofficialCurrencyCode: String?
    
    enum CodingKeys: String, CodingKey {
        case available
        case current
        case limit
        case isoCurrencyCode = "iso_currency_code"
        case unofficialCurrencyCode = "unofficial_currency_code"
    }
    
    /// The most relevant balance value
    var effectiveBalance: Double {
        available ?? current ?? 0.0
    }
    
    /// Currency code (ISO or unofficial)
    var currencyCode: String {
        isoCurrencyCode ?? unofficialCurrencyCode ?? "USD"
    }
}

// MARK: - Plaid Item Model

/// Represents a Plaid Item (bank connection)
struct PlaidItem: Codable, Identifiable, Sendable {
    let itemId: String
    let institutionId: String?
    let webhook: String?
    let error: PlaidItemError?
    let availableProducts: [String]?
    let billedProducts: [String]?
    let consentExpirationTime: Date?
    let updateType: String?
    
    var id: String { itemId }
    
    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case institutionId = "institution_id"
        case webhook
        case error
        case availableProducts = "available_products"
        case billedProducts = "billed_products"
        case consentExpirationTime = "consent_expiration_time"
        case updateType = "update_type"
    }
    
    /// Whether the item has an error requiring action
    var hasError: Bool {
        error != nil
    }
    
    /// Whether the item needs reauthentication
    var needsReauth: Bool {
        error?.errorCode == "ITEM_LOGIN_REQUIRED"
    }
}

/// Plaid item error
struct PlaidItemError: Codable, Sendable {
    let errorType: String
    let errorCode: String
    let errorMessage: String
    let displayMessage: String?
    
    enum CodingKeys: String, CodingKey {
        case errorType = "error_type"
        case errorCode = "error_code"
        case errorMessage = "error_message"
        case displayMessage = "display_message"
    }
}

// MARK: - Plaid Transaction Model

/// Represents a transaction from Plaid
struct PlaidTransaction: Codable, Identifiable, Sendable {
    let transactionId: String
    let accountId: String
    let amount: Double
    let date: Date
    let name: String
    let merchantName: String?
    let category: [String]?
    let categoryId: String?
    let pending: Bool
    let pendingTransactionId: String?
    let accountOwner: String?
    let paymentChannel: String?
    let location: PlaidLocation?
    let paymentMeta: PlaidPaymentMeta?
    let authorizedDate: Date?
    let transactionCode: String?
    let personalFinanceCategory: PlaidPersonalFinanceCategory?
    
    var id: String { transactionId }
    
    enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
        case accountId = "account_id"
        case amount
        case date
        case name
        case merchantName = "merchant_name"
        case category
        case categoryId = "category_id"
        case pending
        case pendingTransactionId = "pending_transaction_id"
        case accountOwner = "account_owner"
        case paymentChannel = "payment_channel"
        case location
        case paymentMeta = "payment_meta"
        case authorizedDate = "authorized_date"
        case transactionCode = "transaction_code"
        case personalFinanceCategory = "personal_finance_category"
    }
    
    /// Whether this is an income transaction
    /// Plaid uses negative amounts for income
    var isIncome: Bool {
        amount < 0
    }
    
    /// Absolute amount (always positive)
    var absoluteAmount: Double {
        abs(amount)
    }
    
    /// Best display name for the transaction
    var displayName: String {
        merchantName ?? name
    }
    
    /// Category hierarchy as a single string
    var categoryString: String? {
        category?.joined(separator: " > ")
    }
}

/// Transaction location information
struct PlaidLocation: Codable, Sendable {
    let address: String?
    let city: String?
    let region: String?
    let postalCode: String?
    let country: String?
    let lat: Double?
    let lon: Double?
    let storeNumber: String?
    
    enum CodingKeys: String, CodingKey {
        case address
        case city
        case region
        case postalCode = "postal_code"
        case country
        case lat
        case lon
        case storeNumber = "store_number"
    }
}

/// Payment metadata
struct PlaidPaymentMeta: Codable, Sendable {
    let referenceNumber: String?
    let ppdId: String?
    let payee: String?
    let byOrderOf: String?
    let payer: String?
    let paymentMethod: String?
    let paymentProcessor: String?
    let reason: String?
    
    enum CodingKeys: String, CodingKey {
        case referenceNumber = "reference_number"
        case ppdId = "ppd_id"
        case payee
        case byOrderOf = "by_order_of"
        case payer
        case paymentMethod = "payment_method"
        case paymentProcessor = "payment_processor"
        case reason
    }
}

/// Personal finance category (Plaid's enhanced categorization)
struct PlaidPersonalFinanceCategory: Codable, Sendable {
    let primary: String
    let detailed: String
    let confidenceLevel: String?
    
    enum CodingKeys: String, CodingKey {
        case primary
        case detailed
        case confidenceLevel = "confidence_level"
    }
}

// MARK: - Institution Model

/// Financial institution information
struct PlaidInstitution: Codable, Identifiable, Sendable {
    let institutionId: String
    let name: String
    let products: [String]?
    let countryCodes: [String]?
    let url: String?
    let primaryColor: String?
    let logo: String?
    let routingNumbers: [String]?
    
    var id: String { institutionId }
    
    enum CodingKeys: String, CodingKey {
        case institutionId = "institution_id"
        case name
        case products
        case countryCodes = "country_codes"
        case url
        case primaryColor = "primary_color"
        case logo
        case routingNumbers = "routing_numbers"
    }
}

// MARK: - Sync Result

/// Result of a transaction sync operation
struct PlaidSyncResult: Sendable {
    let added: Int
    let updated: Int
    let removed: Int
    let skipped: Int
    let cursor: String
    let hasMore: Bool
    
    var total: Int { added + updated + removed }
    
    var description: String {
        if total == 0 {
            return "Already up to date"
        }
        
        var parts: [String] = []
        if added > 0 { parts.append("\(added) new") }
        if updated > 0 { parts.append("\(updated) updated") }
        if removed > 0 { parts.append("\(removed) removed") }
        if skipped > 0 { parts.append("\(skipped) skipped") }
        
        return parts.joined(separator: ", ")
    }
}

// MARK: - Request Models

/// Request body for creating a link token
struct CreateLinkTokenRequest: Codable, Sendable {
    let userId: String
    let clientName: String
    let products: [String]
    let countryCodes: [String]
    let language: String
    let webhook: String?
    let redirectUri: String?
    let accessToken: String?  // For update mode
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case clientName = "client_name"
        case products
        case countryCodes = "country_codes"
        case language
        case webhook
        case redirectUri = "redirect_uri"
        case accessToken = "access_token"
    }
}

/// Request body for exchanging public token
struct ExchangeTokenRequest: Codable, Sendable {
    let publicToken: String
    
    enum CodingKeys: String, CodingKey {
        case publicToken = "public_token"
    }
}

/// Request body for syncing transactions
struct TransactionsSyncRequest: Codable, Sendable {
    let cursor: String?
    let count: Int?
    
    enum CodingKeys: String, CodingKey {
        case cursor
        case count
    }
}

// MARK: - Webhook Models

/// Plaid webhook payload
struct PlaidWebhook: Codable, Sendable {
    let webhookType: String
    let webhookCode: String
    let itemId: String
    let error: PlaidItemError?
    let newTransactions: Int?
    
    enum CodingKeys: String, CodingKey {
        case webhookType = "webhook_type"
        case webhookCode = "webhook_code"
        case itemId = "item_id"
        case error
        case newTransactions = "new_transactions"
    }
}

// MARK: - Keychain Keys

/// Keys used for Keychain storage
enum PlaidKeychainKey {
    static let accessTokenPrefix = "com.finchandpoppy.flo.plaid.accessToken."
    static let itemIdPrefix = "com.finchandpoppy.flo.plaid.itemId."
    static let cursorPrefix = "com.finchandpoppy.flo.plaid.cursor."
    
    static func accessToken(for accountId: UUID) -> String {
        return accessTokenPrefix + accountId.uuidString
    }
    
    static func itemId(for accountId: UUID) -> String {
        return itemIdPrefix + accountId.uuidString
    }
    
    static func cursor(for itemId: String) -> String {
        return cursorPrefix + itemId
    }
}

// MARK: - Date Decoding

/// Custom date formatter for Plaid API responses
extension JSONDecoder {
    static var plaidDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try ISO8601 with fractional seconds
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFormatter.date(from: dateString) {
                return date
            }
            
            // Try ISO8601 without fractional seconds
            isoFormatter.formatOptions = [.withInternetDateTime]
            if let date = isoFormatter.date(from: dateString) {
                return date
            }
            
            // Try date-only format (YYYY-MM-DD)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateFormatter.timeZone = TimeZone(identifier: "UTC")
            if let date = dateFormatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }
        return decoder
    }
}
