//  BusinessProfileSettingsView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.0 - Multi-Business List + Detail Pattern
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v3.0:
//  ✅ REWRITE: List+Detail pattern supporting up to 5 businesses
//  ✅ ADDED: BusinessListView showing all business profiles
//  ✅ ADDED: Business type picker, color, and icon configuration
//  ✅ ADDED: Add/deactivate business support
//  ✅ RETAINED: All v2.3 form fields, animations, and accessibility
//

import SwiftUI
import FLODesignSystem
import SwiftData

// MARK: - Business List View (New Entry Point)

struct BusinessListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<BusinessProfile> { $0.isActive },
        sort: \BusinessProfile.sortOrder
    )
    private var businesses: [BusinessProfile]

    @State private var showingAddBusiness = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ProfileHeaderCard(
                    icon: "building.2.fill",
                    title: "Your Businesses",
                    subtitle: "Manage up to \(BusinessProfileService.maxBusinesses) business profiles",
                    color: .businessColor
                )

                ForEach(businesses) { business in
                    NavigationLink(value: business) {
                        BusinessRowCard(business: business)
                    }
                    .buttonStyle(.plain)
                }

                if businesses.count < BusinessProfileService.maxBusinesses {
                    Button {
                        showingAddBusiness = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                            Text("Add Business")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }

                if businesses.isEmpty {
                    ProfileFooterNote(
                        icon: "info.circle",
                        text: "Add your first business to get started with multi-business tracking."
                    )
                } else {
                    ProfileFooterNote(
                        icon: "doc.text.fill",
                        text: "Business information appears on invoices and tax reports."
                    )
                }
            }
            .padding(16)
        }
        .navigationTitle("Businesses")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationDestination(for: BusinessProfile.self) { business in
            BusinessProfileSettingsView(business: business)
        }
        .sheet(isPresented: $showingAddBusiness) {
            AddBusinessOnboardingView()
        }
        .onAppear {
            // Auto-migrate: if there are no businesses, check for legacy singleton
            if businesses.isEmpty {
                migrateFromSingleton()
            }
        }
    }

    private func migrateFromSingleton() {
        // Check if there's a legacy BusinessProfile without isPrimary set
        let descriptor = FetchDescriptor<BusinessProfile>()
        guard let allProfiles = try? modelContext.fetch(descriptor),
              let legacy = allProfiles.first,
              !legacy.isPrimary else { return }

        legacy.isPrimary = true
        legacy.isActive = true
        legacy.sortOrder = 0
        if legacy.businessTypeRaw.isEmpty {
            legacy.businessType = .soleProprietorship
        }

        // Auto-create TaxSettings if missing
        if legacy.taxSettings == nil {
            let existingSettings = try? modelContext.fetch(FetchDescriptor<TaxSettings>())
            if let settings = existingSettings?.first {
                settings.businessProfile = legacy
            } else {
                let settings = TaxSettings()
                settings.businessProfile = legacy
                modelContext.insert(settings)
            }
        }

        try? modelContext.save()
    }
}

// MARK: - Business Row Card

struct BusinessRowCard: View {
    let business: BusinessProfile

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: business.displayIcon)
                .font(.title2)
                .foregroundStyle(business.isPrimary ? .blue : .secondary)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(business.businessName)
                        .font(.headline)
                        .lineLimit(1)
                    if business.isPrimary {
                        Text("Primary")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }
                Text(business.businessType.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let email = business.email.isEmpty ? nil : business.email {
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Add Business View

struct AddBusinessView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var businessName = ""
    @State private var email = ""
    @State private var businessType: BusinessType = .soleProprietorship

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ProfileHeaderCard(
                    icon: "plus.circle.fill",
                    title: "Add Business",
                    subtitle: "Set up a new business profile",
                    color: .green
                )

                ProfileSectionCard(title: "Business Details") {
                    ProfileFieldRow(
                        label: "Business Name",
                        placeholder: "e.g., Anderson Farm",
                        text: $businessName,
                        isValid: businessName.isEmpty ? nil : true,
                        isRequired: true
                    )

                    ProfileFieldRow(
                        label: "Email",
                        placeholder: "business@example.com",
                        text: $email,
                        isValid: email.isEmpty ? nil : email.contains("@"),
                        isRequired: true,
                        capitalize: false
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Business Type")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Picker("Business Type", selection: $businessType) {
                            ForEach(BusinessType.allCases, id: \.self) { type in
                                Label(type.displayName, systemImage: type.defaultIcon)
                                    .tag(type)
                            }
                        }
                        .pickerStyle(.menu)

                        Text("Tax form: \(businessType.taxFormName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(16)
        }
        .navigationTitle("Add Business")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    addBusiness()
                }
                .disabled(!isValid)
                .fontWeight(.semibold)
            }
        }
    }

    private var isValid: Bool {
        !businessName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        email.contains("@")
    }

    private func addBusiness() {
        let _ = BusinessProfileService.shared.createProfile(
            businessName: businessName.trimmingCharacters(in: .whitespaces),
            email: email.trimmingCharacters(in: .whitespaces),
            businessType: businessType,
            context: modelContext
        )
        HapticService.shared.success()
        dismiss()
    }
}

// MARK: - Business Profile Detail (Existing Form, Enhanced)

struct BusinessProfileSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// The business profile being edited (passed from list)
    var business: BusinessProfile?

    @State private var profile: BusinessProfile?

    // Form fields
    @State private var businessName: String = ""
    @State private var contactName: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var address: String = ""
    @State private var city: String = ""
    @State private var state: String = ""
    @State private var zipCode: String = ""
    @State private var country: String = ""
    @State private var website: String = ""
    @State private var taxId: String = ""
    @State private var businessType: BusinessType = .soleProprietorship

    @State private var showingSaveConfirmation = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var hasChanges = false

    // Animation States
    @State private var headerScale: CGFloat = 0.9
    @State private var headerOpacity: Double = 0
    @State private var requiredSectionOpacity: Double = 0
    @State private var optionalSectionOpacity: Double = 0
    @State private var addressSectionOpacity: Double = 0
    @State private var footerOpacity: Double = 0
    @State private var saveButtonPressed = false
    @State private var showSavedCheck = false
    @State private var nameFieldShake = false
    @State private var emailFieldShake = false
    @State private var isSaving = false

    // Validation visual states
    @State private var nameValidationColor: Color = .secondary
    @State private var emailValidationColor: Color = .secondary

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection
                businessTypeSection
                requiredInfoSection
                optionalInfoSection
                addressSection
                actionsSection
                footerSection
            }
            .padding(16)
        }
        .navigationTitle(profile?.businessName ?? "Business Profile")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    saveProfile()
                } label: {
                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("Save")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(!isValid || isSaving)
                .scaleEffect(saveButtonPressed ? 0.9 : 1.0)
            }
        }
        .onAppear {
            loadProfile()
            animateEntrance()
            AccessibilityAnnouncement.screenChanged("Business profile")
        }
        .alert("Profile Saved", isPresented: $showingSaveConfirmation) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your business profile has been updated successfully.")
        }
        .alert("Save Failed", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Extracted Sections

    private var headerSection: some View {
        ProfileHeaderCard(
            icon: profile?.displayIcon ?? "building.2.fill",
            title: profile?.businessName ?? "Business Profile",
            subtitle: headerSubtitle,
            color: .businessColor
        )
        .scaleEffect(headerScale)
        .opacity(headerOpacity)
    }

    private var headerSubtitle: String {
        if let p = profile {
            return "\(p.businessType.displayName) - \(p.businessType.taxFormName)"
        }
        return "This information appears on your invoices"
    }

    private var businessTypeSection: some View {
        ProfileSectionCard(title: "Business Type") {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Type", selection: $businessType) {
                    ForEach(BusinessType.allCases, id: \.self) { type in
                        Label(type.displayName, systemImage: type.defaultIcon)
                            .tag(type)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: businessType) { _, _ in hasChanges = true }

                Text("Tax form: \(businessType.taxFormName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .opacity(requiredSectionOpacity)
    }

    private var requiredInfoSection: some View {
        ProfileSectionCard(title: "Required Information") {
            ProfileFieldRow(
                label: "Business Name",
                placeholder: "Your Business Name",
                text: $businessName,
                isValid: businessName.isEmpty ? nil : true,
                isRequired: true
            )
            .onChange(of: businessName) { _, newValue in
                hasChanges = true
                withAnimation(.easeInOut(duration: 0.2)) {
                    nameValidationColor = newValue.isEmpty ? .orange : .secondary
                }
            }

            ProfileFieldRow(
                label: "Email",
                placeholder: "business@example.com",
                text: $email,
                isValid: email.isEmpty ? nil : email.contains("@"),
                isRequired: true,
                capitalize: false
            )
            .onChange(of: email) { _, newValue in
                hasChanges = true
                withAnimation(.easeInOut(duration: 0.2)) {
                    if newValue.isEmpty { emailValidationColor = .orange }
                    else if !newValue.contains("@") { emailValidationColor = .red }
                    else { emailValidationColor = .secondary }
                }
            }
        }
        .opacity(requiredSectionOpacity)
    }

    private var optionalInfoSection: some View {
        ProfileSectionCard(title: "Optional Information") {
            ProfileFieldRow(label: "Contact Name", placeholder: "Your Name", text: $contactName)
                .onChange(of: contactName) { _, _ in hasChanges = true }
            ProfileFieldRow(label: "Phone", placeholder: "(555) 123-4567", text: $phone)
                .onChange(of: phone) { _, _ in hasChanges = true }
            ProfileFieldRow(label: "Website", placeholder: "www.yourbusiness.com", text: $website, capitalize: false)
                .onChange(of: website) { _, _ in hasChanges = true }
            ProfileFieldRow(label: "Tax ID / EIN", placeholder: "12-3456789", text: $taxId, capitalize: false)
                .onChange(of: taxId) { _, _ in hasChanges = true }
        }
        .opacity(optionalSectionOpacity)
    }

    private var addressSection: some View {
        ProfileSectionCard(title: "Business Address") {
            ProfileFieldRow(label: "Street Address", placeholder: "123 Main Street", text: $address)
                .onChange(of: address) { _, _ in hasChanges = true }
            ProfileFieldRow(label: "City", placeholder: "City", text: $city)
                .onChange(of: city) { _, _ in hasChanges = true }
            ProfileFieldRowPair(
                label1: "State", placeholder1: "State", text1: $state,
                label2: "ZIP", placeholder2: "12345", text2: $zipCode
            )
            .onChange(of: state) { _, _ in hasChanges = true }
            .onChange(of: zipCode) { _, _ in hasChanges = true }
            ProfileFieldRow(label: "Country", placeholder: "United States", text: $country)
                .onChange(of: country) { _, _ in hasChanges = true }
        }
        .opacity(addressSectionOpacity)
    }

    @ViewBuilder
    private var actionsSection: some View {
        if let profile = profile, !profile.isPrimary {
            ProfileSectionCard(title: "Actions") {
                Button {
                    BusinessProfileService.shared.setPrimary(profile, context: modelContext)
                    HapticService.shared.success()
                } label: {
                    Label("Set as Primary Business", systemImage: "star.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)

                Button(role: .destructive) {
                    BusinessProfileService.shared.deactivateProfile(profile, context: modelContext)
                    HapticService.shared.mediumImpact()
                    dismiss()
                } label: {
                    Label("Deactivate Business", systemImage: "archivebox")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
            .opacity(footerOpacity)
        }
    }

    @ViewBuilder
    private var footerSection: some View {
        if showSavedCheck {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Saved!")
                    .fontWeight(.medium)
                    .foregroundStyle(.green)
            }
            .transition(.scale.combined(with: .opacity))
        } else {
            ProfileFooterNote(
                icon: "doc.text.fill",
                text: "This information will appear on all invoices for this business."
            )
        }
    }

    // MARK: - Animations

    private func animateEntrance() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            headerScale = 1.0
            headerOpacity = 1.0
        }

        withAnimation(.easeOut(duration: 0.3).delay(0.1)) {
            requiredSectionOpacity = 1.0
        }

        withAnimation(.easeOut(duration: 0.3).delay(0.2)) {
            optionalSectionOpacity = 1.0
        }

        withAnimation(.easeOut(duration: 0.3).delay(0.3)) {
            addressSectionOpacity = 1.0
        }

        withAnimation(.easeOut(duration: 0.3).delay(0.4)) {
            footerOpacity = 1.0
        }
    }

    private func triggerValidationShake(for field: String) {
        HapticService.shared.error()

        if field == "name" {
            withAnimation(.easeInOut(duration: 0.05).repeatCount(5, autoreverses: true)) {
                nameFieldShake = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                nameFieldShake = false
            }
        } else if field == "email" {
            withAnimation(.easeInOut(duration: 0.05).repeatCount(5, autoreverses: true)) {
                emailFieldShake = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                emailFieldShake = false
            }
        }
    }

    // MARK: - Computed Properties

    private var isValid: Bool {
        !businessName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        email.contains("@")
    }

    // MARK: - Methods

    private func loadProfile() {
        // Use the passed-in business, or fall back to fetching primary
        profile = business ?? BusinessProfileService.shared.fetchProfile(context: modelContext)

        if let profile = profile {
            businessName = profile.businessName
            contactName = profile.contactName ?? ""
            email = profile.email
            phone = profile.phone ?? ""
            address = profile.address ?? ""
            city = profile.city ?? ""
            state = profile.state ?? ""
            zipCode = profile.zipCode ?? ""
            country = profile.country ?? ""
            website = profile.website ?? ""
            taxId = profile.taxId ?? ""
            businessType = profile.businessType
        }

        hasChanges = false
    }

    private func saveProfile() {
        let trimmedBusinessName = businessName.trimmingCharacters(in: .whitespaces)
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)

        if trimmedBusinessName.isEmpty {
            triggerValidationShake(for: "name")
            return
        }

        if trimmedEmail.isEmpty || !trimmedEmail.contains("@") {
            triggerValidationShake(for: "email")
            return
        }

        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            saveButtonPressed = true
        }

        isSaving = true
        HapticService.play(.heavy)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                saveButtonPressed = false
            }
        }

        if let existingProfile = profile {
            existingProfile.businessName = trimmedBusinessName
            existingProfile.email = trimmedEmail
            existingProfile.contactName = contactName.isEmpty ? nil : contactName
            existingProfile.phone = phone.isEmpty ? nil : phone
            existingProfile.address = address.isEmpty ? nil : address
            existingProfile.city = city.isEmpty ? nil : city
            existingProfile.state = state.isEmpty ? nil : state
            existingProfile.zipCode = zipCode.isEmpty ? nil : zipCode
            existingProfile.country = country.isEmpty ? nil : country
            existingProfile.website = website.isEmpty ? nil : website
            existingProfile.taxId = taxId.isEmpty ? nil : taxId
            existingProfile.businessType = businessType
            existingProfile.updateModifiedDate()

            performSave()
        } else {
            let newProfile = BusinessProfileService.shared.createProfile(
                businessName: trimmedBusinessName,
                email: trimmedEmail,
                businessType: businessType,
                isPrimary: true,
                context: modelContext
            )
            profile = newProfile

            // Update remaining fields
            newProfile.contactName = contactName.isEmpty ? nil : contactName
            newProfile.phone = phone.isEmpty ? nil : phone
            newProfile.address = address.isEmpty ? nil : address
            newProfile.city = city.isEmpty ? nil : city
            newProfile.state = state.isEmpty ? nil : state
            newProfile.zipCode = zipCode.isEmpty ? nil : zipCode
            newProfile.country = country.isEmpty ? nil : country
            newProfile.website = website.isEmpty ? nil : website
            newProfile.taxId = taxId.isEmpty ? nil : taxId

            performSave()
        }
    }

    private func performSave() {
        do {
            try modelContext.save()

            UserDefaults.standard.set(true, forKey: "hasBusinessProfileSetup")

            HapticService.shared.success()

            withAnimation(FLOAnimation.quick) {
                showSavedCheck = true
            }

            hasChanges = false
            isSaving = false

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(FLOAnimation.quickEase) {
                    showSavedCheck = false
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showingSaveConfirmation = true
                }
            }
        } catch {
            HapticService.shared.error()
            isSaving = false
            errorMessage = "Failed to save profile: \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }
}

#Preview {
    NavigationStack {
        BusinessListView()
            .modelContainer(ModelContainer.preview())
    }
}

#Preview("Detail") {
    NavigationStack {
        BusinessProfileSettingsView()
            .modelContainer(ModelContainer.preview())
    }
}
