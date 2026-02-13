//  BusinessProfile.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Initial Business Profile Model
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Stores user's business information for invoices, reports, and branding.
//  Singleton pattern - only one BusinessProfile should exist per user.
//

import Foundation
import SwiftData

@Model
final class BusinessProfile {
    // MARK: - Properties
    
    /// Unique identifier
    var id: UUID
    
    /// Business or personal name (required)
    var businessName: String
    
    /// Contact name (optional - for DBA or personal branding)
    var contactName: String?
    
    /// Business email address (required)
    var email: String
    
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
    var createdDate: Date
    
    /// Date profile was last modified
    var modifiedDate: Date
    
    // MARK: - Computed Properties
    
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
        taxId: String? = nil
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
        self.createdDate = Date()
        self.modifiedDate = Date()
    }
    
    // MARK: - Update Methods
    
    func updateModifiedDate() {
        modifiedDate = Date()
    }
}

// MARK: - Business Profile Service

@MainActor
class BusinessProfileService {
    static let shared = BusinessProfileService()
    
    private init() {}
    
    /// Fetch the user's business profile (should only be one)
    func fetchProfile(context: ModelContext) -> BusinessProfile? {
        let descriptor = FetchDescriptor<BusinessProfile>()
        let profiles = try? context.fetch(descriptor)
        return profiles?.first
    }
    
    /// Create initial business profile
    func createProfile(
        businessName: String,
        email: String,
        context: ModelContext
    ) -> BusinessProfile {
        let profile = BusinessProfile(
            businessName: businessName,
            email: email
        )
        context.insert(profile)
        
        do {
            try context.save()
        } catch {
            print("❌ Failed to save business profile: \(error)")
        }
        
        return profile
    }
    
    /// Get or create business profile (ensures one always exists)
    func getOrCreateProfile(context: ModelContext) -> BusinessProfile {
        if let existing = fetchProfile(context: context) {
            return existing
        }
        
        // Create default profile
        return createProfile(
            businessName: "My Business",
            email: "hello@mybusiness.com",
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
            print("❌ Failed to update business profile: \(error)")
        }
    }
    
    /// Delete business profile (with confirmation - should rarely be used)
    func deleteProfile(_ profile: BusinessProfile, context: ModelContext) {
        context.delete(profile)
        
        do {
            try context.save()
        } catch {
            print("❌ Failed to delete business profile: \(error)")
        }
    }
}
