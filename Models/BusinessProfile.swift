//  BusinessProfile.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.1 - Partnership tracking, NAICS, accounting method, asset/carryforward relationships
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Stores business information for invoices, reports, tax handoff, and branding.
//  Supports multiple business profiles per user (max 5).
//
//  CHANGES v2.1:
//  ✅ ADDED: naicsCode, accountingMethodRaw, formationDate for tax handoff
//  ✅ ADDED: partners relationship (PartnerAllocation) for K-1 tracking
//  ✅ ADDED: assets relationship (DepreciableAsset) for depreciation schedules
//  ✅ ADDED: carryforwards relationship (TaxCarryforward) for multi-year tax items
//  ✅ ADDED: AccountingMethod enum (cash, accrual)
//  ✅ ADDED: isPartnership computed property
//  ✅ ADDED: BusinessType .partnership case for Form 1065 filers
//
//  CHANGES v2.0:
//  ✅ REWRITE: Singleton pattern removed — supports 1-5 business profiles
//  ✅ ADDED: isPrimary, isActive, sortOrder for multi-profile management
//  ✅ ADDED: businessTypeRaw / BusinessType enum (LLC, farm, sole prop, etc.)
//  ✅ ADDED: colorHex, iconName for UI differentiation
//  ✅ ADDED: Relationships to Account, TaxSettings, Invoice
//  ✅ ADDED: BusinessType enum with tax form mapping
//  ✅ RETAINED: All v1.0 contact/address fields
//

import Foundation
import SwiftData

@Model
final class BusinessProfile {
    // MARK: - Properties

    /// Unique identifier
    var id: UUID = UUID()

    /// Business or personal name (required)
    var businessName: String = ""

    /// Contact name (optional - for DBA or personal branding)
    var contactName: String?

    /// Business email address (required)
    var email: String = ""

    /// Phone number (optional)
    var phone: String?

    /// Address fields (all optional)
    var address: String?
    var city: String?
    var state: String?
    var zipCode: String?
    var country: String?

    /// Website URL (optional)
    var website: String?

    /// Tax ID / EIN (optional)
    var taxId: String?

    /// Date profile was created
    var createdDate: Date = Date()

    /// Date profile was last modified
    var modifiedDate: Date = Date()

    // MARK: - Tax Handoff Properties (v2.1)

    /// NAICS industry classification code (e.g., "112900" for Animal Production)
    var naicsCode: String?

    /// Raw backing for accounting method enum
    var accountingMethodRaw: String?

    /// Date the entity was legally formed/organized
    var formationDate: Date?

    /// Typed accessor for accounting method
    var accountingMethod: AccountingMethod {
        get { AccountingMethod(rawValue: accountingMethodRaw ?? "") ?? .cash }
        set { accountingMethodRaw = newValue.rawValue }
    }

    // MARK: - Multi-Business Properties (v2.0)

    /// Whether this is the primary/default business
    var isPrimary: Bool = false

    /// Soft delete support — inactive businesses are hidden but data preserved
    var isActive: Bool = true

    /// User-defined ordering for display
    var sortOrder: Int = 0

    /// Backing storage for BusinessType enum (SwiftData-safe raw string)
    var businessTypeRaw: String = BusinessType.soleProprietorship.rawValue

    /// Brand color for UI differentiation (hex string, e.g., "#4A90D9")
    var colorHex: String?

    /// SF Symbol name for business icon (e.g., "leaf.fill" for farm)
    var iconName: String?

    // MARK: - Relationships (v2.0)

    /// Accounts belonging to this business (nil = personal accounts)
    @Relationship(deleteRule: .nullify, inverse: \Account.businessProfile)
    var accounts: [Account]?

    /// Per-business tax settings (one-to-one)
    @Relationship(deleteRule: .cascade, inverse: \TaxSettings.businessProfile)
    var taxSettings: TaxSettings?

    /// Invoices issued by this business
    @Relationship(deleteRule: .nullify, inverse: \Invoice.businessProfile)
    var invoices: [Invoice]?

    /// Partners/members in this business (for partnerships/LLCs)
    @Relationship(deleteRule: .cascade, inverse: \PartnerAllocation.businessProfile)
    var partners: [PartnerAllocation]?

    /// Depreciable assets owned by this business
    @Relationship(deleteRule: .cascade, inverse: \DepreciableAsset.businessProfile)
    var assets: [DepreciableAsset]?

    /// Tax carryforward items for this business
    @Relationship(deleteRule: .cascade, inverse: \TaxCarryforward.businessProfile)
    var carryforwards: [TaxCarryforward]?

    /// Filing jurisdictions for this business (state, county, city)
    @Relationship(deleteRule: .cascade, inverse: \EntityJurisdiction.businessProfile)
    var jurisdictions: [EntityJurisdiction]?

    /// Budgets scoped to this business
    @Relationship(deleteRule: .nullify, inverse: \Budget.businessProfile)
    var budgets: [Budget]?

    /// Mileage trips for this business
    @Relationship(deleteRule: .nullify, inverse: \MileageTrip.businessProfile)
    var mileageTrips: [MileageTrip]?

    /// Recurring transactions for this business
    @Relationship(deleteRule: .nullify, inverse: \RecurringTransaction.businessProfile)
    var recurringTransactions: [RecurringTransaction]?

    // MARK: - Computed Properties

    /// Typed accessor for business type
    var businessType: BusinessType {
        get { BusinessType(rawValue: businessTypeRaw) ?? .soleProprietorship }
        set { businessTypeRaw = newValue.rawValue }
    }

    /// Full formatted address for invoices
    var formattedAddress: String? {
        var components: [String] = []

        if let address = address, !address.isEmpty {
            components.append(address)
        }

        var cityStateZip: [String] = []
        if let city = city, !city.isEmpty {
            cityStateZip.append(city)
        }
        if let state = state, !state.isEmpty {
            cityStateZip.append(state)
        }
        if let zip = zipCode, !zip.isEmpty {
            cityStateZip.append(zip)
        }

        if !cityStateZip.isEmpty {
            components.append(cityStateZip.joined(separator: ", "))
        }

        if let country = country, !country.isEmpty {
            components.append(country)
        }

        return components.isEmpty ? nil : components.joined(separator: "\n")
    }

    /// Whether profile has minimum required info for invoices
    var isComplete: Bool {
        !businessName.isEmpty && !email.isEmpty
    }

    /// Sanitized business name for filenames (removes special characters)
    var safeBusinessName: String {
        businessName
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "&", with: "and")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-")).inverted)
            .joined()
    }

    /// Whether this business is a farm (affects tax form selection)
    var isFarm: Bool {
        businessType == .farm
    }

    /// Whether this business files as a partnership (Form 1065)
    var isPartnership: Bool {
        businessType == .llc || businessType == .partnership
    }

    /// The tax form type for this business
    var taxFormType: TaxFormType {
        TaxFormType.formType(for: businessType)
    }

    /// Sorted partners by ownership percentage (descending)
    var sortedPartners: [PartnerAllocation] {
        (partners ?? []).sorted { $0.ownershipPercentage > $1.ownershipPercentage }
    }

    /// Active depreciable assets
    var activeAssets: [DepreciableAsset] {
        (assets ?? []).filter { $0.isActive }
    }

    /// Active carryforward items
    var activeCarryforwards: [TaxCarryforward] {
        (carryforwards ?? []).filter { $0.isActive }
    }

    /// Active filing jurisdictions
    var activeJurisdictions: [EntityJurisdiction] {
        (jurisdictions ?? []).filter { $0.isActive }
    }

    /// NAICS display string (e.g., "112900 — Other Animal Production")
    var naicsDisplay: String? {
        naicsCode
    }

    /// Display icon — uses custom iconName or falls back to type default
    var displayIcon: String {
        iconName ?? businessType.defaultIcon
    }

    /// Number of linked accounts
    var accountCount: Int {
        accounts?.count ?? 0
    }

    // MARK: - Initialization

    init(
        businessName: String,
        email: String,
        contactName: String? = nil,
        phone: String? = nil,
        address: String? = nil,
        city: String? = nil,
        state: String? = nil,
        zipCode: String? = nil,
        country: String? = nil,
        website: String? = nil,
        taxId: String? = nil,
        isPrimary: Bool = false,
        isActive: Bool = true,
        sortOrder: Int = 0,
        businessType: BusinessType = .soleProprietorship,
        colorHex: String? = nil,
        iconName: String? = nil
    ) {
        self.id = UUID()
        self.businessName = businessName
        self.email = email
        self.contactName = contactName
        self.phone = phone
        self.address = address
        self.city = city
        self.state = state
        self.zipCode = zipCode
        self.country = country
        self.website = website
        self.taxId = taxId
        self.isPrimary = isPrimary
        self.isActive = isActive
        self.sortOrder = sortOrder
        self.businessTypeRaw = businessType.rawValue
        self.colorHex = colorHex
        self.iconName = iconName
        self.createdDate = Date()
        self.modifiedDate = Date()
    }

    // MARK: - Update Methods

    func updateModifiedDate() {
        modifiedDate = Date()
    }
}

// MARK: - Protocol Conformances

extension BusinessProfile: Hashable {
    static func == (lhs: BusinessProfile, rhs: BusinessProfile) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Business Type Enum

enum BusinessType: String, CaseIterable, Codable {
    case soleProprietorship = "soleProprietorship"
    case llc = "llc"
    case partnership = "partnership"
    case farm = "farm"
    case rentalProperty = "rentalProperty"
    case other = "other"

    var displayName: String {
        switch self {
        case .soleProprietorship: return "Sole Proprietorship"
        case .llc: return "LLC"
        case .partnership: return "Partnership"
        case .farm: return "Farm"
        case .rentalProperty: return "Rental Property"
        case .other: return "Other"
        }
    }

    /// IRS tax form for this business type
    var taxFormName: String {
        switch self {
        case .soleProprietorship: return "Schedule C"
        case .llc, .partnership:  return "Form 1065"
        case .farm:               return "Schedule F"
        case .rentalProperty:     return "Schedule E"
        case .other:              return "Schedule C"
        }
    }

    /// Default SF Symbol icon for this type
    var defaultIcon: String {
        switch self {
        case .soleProprietorship: return "person.fill"
        case .llc:                return "building.2.fill"
        case .partnership:        return "person.2.fill"
        case .farm:               return "leaf.fill"
        case .rentalProperty:     return "house.fill"
        case .other:              return "briefcase.fill"
        }
    }

    /// Whether this type typically has self-employment tax
    var hasSelfEmploymentTax: Bool {
        switch self {
        case .soleProprietorship, .llc, .partnership, .farm, .other: return true
        case .rentalProperty: return false
        }
    }

    /// Whether this type files a partnership return (Form 1065)
    var isPartnershipFiling: Bool {
        switch self {
        case .llc, .partnership: return true
        default: return false
        }
    }

    /// Brief tax implications summary for this business type
    var taxImplications: String {
        switch self {
        case .soleProprietorship:
            return "Income reported on your personal return (Schedule C). Subject to self-employment tax (15.3%). Simplest business structure."
        case .llc:
            return "Default: taxed as sole prop or partnership. Can elect S-corp taxation. Provides liability protection. Self-employment tax applies."
        case .partnership:
            return "Requires Form 1065 + Schedule K-1 per partner. Due March 15. Each partner reports their share on their personal return."
        case .farm:
            return "Schedule F with special provisions. Cash accounting allowed regardless of gross receipts. Estimated tax exemptions available."
        case .rentalProperty:
            return "Schedule E — passive income. Not subject to self-employment tax. Depreciation deductions available (27.5 years residential)."
        case .other:
            return "Tax treatment depends on your specific entity structure. Consult a tax professional for guidance."
        }
    }
}

// MARK: - Accounting Method Enum

enum AccountingMethod: String, Codable, CaseIterable {
    case cash    = "cash"
    case accrual = "accrual"

    var displayName: String {
        switch self {
        case .cash:    return "Cash Basis"
        case .accrual: return "Accrual Basis"
        }
    }
}

// MARK: - Business Profile Service

@MainActor
class BusinessProfileService {
    static let shared = BusinessProfileService()

    static let maxBusinesses = 5

    private init() {}

    /// Fetch all active business profiles, ordered by sortOrder
    func fetchAllProfiles(context: ModelContext) -> [BusinessProfile] {
        var descriptor = FetchDescriptor<BusinessProfile>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Fetch primary business profile
    func fetchPrimaryProfile(context: ModelContext) -> BusinessProfile? {
        var descriptor = FetchDescriptor<BusinessProfile>(
            predicate: #Predicate { $0.isPrimary && $0.isActive }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    /// Fetch the user's business profile (v1.0 compatibility — returns primary)
    func fetchProfile(context: ModelContext) -> BusinessProfile? {
        fetchPrimaryProfile(context: context) ?? fetchAllProfiles(context: context).first
    }

    /// Can user add another business?
    func canAddBusiness(context: ModelContext) -> Bool {
        fetchAllProfiles(context: context).count < Self.maxBusinesses
    }

    /// Create a new business profile
    func createProfile(
        businessName: String,
        email: String,
        businessType: BusinessType = .soleProprietorship,
        isPrimary: Bool = false,
        context: ModelContext
    ) -> BusinessProfile {
        let allProfiles = fetchAllProfiles(context: context)

        // First profile is always primary
        let shouldBePrimary = isPrimary || allProfiles.isEmpty

        let profile = BusinessProfile(
            businessName: businessName,
            email: email,
            isPrimary: shouldBePrimary,
            sortOrder: allProfiles.count,
            businessType: businessType
        )
        context.insert(profile)

        // Auto-create TaxSettings for this business
        let taxSettings = TaxSettings()
        taxSettings.businessProfile = profile
        context.insert(taxSettings)

        do {
            try context.save()
        } catch {
            print("Failed to save business profile: \(error)")
        }

        return profile
    }

    /// Get or create business profile (ensures one always exists — v1.0 compat)
    func getOrCreateProfile(context: ModelContext) -> BusinessProfile {
        if let existing = fetchProfile(context: context) {
            return existing
        }

        return createProfile(
            businessName: "My Business",
            email: "hello@mybusiness.com",
            isPrimary: true,
            context: context
        )
    }

    /// Update existing profile
    func updateProfile(
        _ profile: BusinessProfile,
        businessName: String,
        email: String,
        contactName: String?,
        phone: String?,
        address: String?,
        city: String?,
        state: String?,
        zipCode: String?,
        country: String?,
        website: String?,
        taxId: String?,
        context: ModelContext
    ) {
        profile.businessName = businessName
        profile.email = email
        profile.contactName = contactName
        profile.phone = phone
        profile.address = address
        profile.city = city
        profile.state = state
        profile.zipCode = zipCode
        profile.country = country
        profile.website = website
        profile.taxId = taxId
        profile.updateModifiedDate()

        do {
            try context.save()
        } catch {
            print("Failed to update business profile: \(error)")
        }
    }

    /// Set a profile as the primary business
    func setPrimary(_ profile: BusinessProfile, context: ModelContext) {
        let allProfiles = fetchAllProfiles(context: context)
        for p in allProfiles {
            p.isPrimary = (p.id == profile.id)
        }

        do {
            try context.save()
        } catch {
            print("Failed to set primary business: \(error)")
        }
    }

    /// Deactivate a business profile (soft delete)
    func deactivateProfile(_ profile: BusinessProfile, context: ModelContext) {
        profile.isActive = false
        profile.updateModifiedDate()

        // If this was primary, promote the next active profile
        if profile.isPrimary {
            profile.isPrimary = false
            if let next = fetchAllProfiles(context: context).first {
                next.isPrimary = true
            }
        }

        do {
            try context.save()
        } catch {
            print("Failed to deactivate business profile: \(error)")
        }
    }

    /// Delete business profile (with confirmation - should rarely be used)
    func deleteProfile(_ profile: BusinessProfile, context: ModelContext) {
        context.delete(profile)

        do {
            try context.save()
        } catch {
            print("Failed to delete business profile: \(error)")
        }
    }
}
