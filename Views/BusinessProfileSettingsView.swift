//  BusinessProfileSettingsView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.2 - Accessibility audit (Sprint 6d)
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v2.2:
//  ✅ Screen change announcement on appear
//  ✅ Header icon hidden from VoiceOver
//  ✅ Validation checkmarks hidden from VoiceOver
//  ✅ Fixed garbled UTF-8 characters in print statements
//
//  Business profile settings for invoice customization
//
//  ENHANCEMENTS v2.0:
//  - Haptic feedback on save, field focus, and validation
//  - Animated header with business icon bounce
//  - Section reveal animations with staggered timing
//  - Save button press animation with scale effect
//  - Success confirmation with checkmark animation
//  - Field validation feedback with color transitions
//  - Error shake animation on validation failure
//

import SwiftUI
import SwiftData

struct BusinessProfileSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
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
        Form {
            // Header Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(Color.businessColor.opacity(0.2))
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: "building.2.fill")
                                .font(.title2)
                                .foregroundStyle(Color.businessColor)
                                .symbolEffect(.bounce, options: .speed(0.5), value: headerOpacity > 0)
                        }
                        .accessibilityHidden(true)
                        
                        VStack(alignment: .leading) {
                            Text("Business Profile")
                                .font(.title2.bold())
                            Text("This information appears on your invoices")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .scaleEffect(headerScale)
                .opacity(headerOpacity)
            }
            .listRowBackground(Color.clear)
            
            // Required Information Section
            Section("Required Information") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Business Name")
                            .font(.caption)
                            .foregroundStyle(nameValidationColor)
                        
                        if !businessName.isEmpty {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                                .transition(.scale.combined(with: .opacity))
                                .accessibilityHidden(true)
                        }
                    }
                    
                    TextField("Your Business Name", text: $businessName)
                        .textInputAutocapitalization(.words)
                        .offset(x: nameFieldShake ? -5 : 0)
                        .onChange(of: businessName) { _, newValue in
                            hasChanges = true
                            withAnimation(.easeInOut(duration: 0.2)) {
                                nameValidationColor = newValue.isEmpty ? .orange : .secondary
                            }
                        }
                }
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: !businessName.isEmpty)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Email")
                            .font(.caption)
                            .foregroundStyle(emailValidationColor)
                        
                        if !email.isEmpty && email.contains("@") {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                                .transition(.scale.combined(with: .opacity))
                                .accessibilityHidden(true)
                        }
                    }
                    
                    TextField("business@example.com", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .offset(x: emailFieldShake ? -5 : 0)
                        .onChange(of: email) { _, newValue in
                            hasChanges = true
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if newValue.isEmpty {
                                    emailValidationColor = .orange
                                } else if !newValue.contains("@") {
                                    emailValidationColor = .red
                                } else {
                                    emailValidationColor = .secondary
                                }
                            }
                        }
                }
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: !email.isEmpty && email.contains("@"))
            }
            .opacity(requiredSectionOpacity)
            
            // Optional Information Section
            Section("Optional Information") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Contact Name")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Your Name", text: $contactName)
                        .textInputAutocapitalization(.words)
                        .onChange(of: contactName) { _, _ in hasChanges = true }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Phone")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("(555) 123-4567", text: $phone)
                        .keyboardType(.phonePad)
                        .onChange(of: phone) { _, _ in hasChanges = true }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Website")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("www.yourbusiness.com", text: $website)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .onChange(of: website) { _, _ in hasChanges = true }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tax ID / EIN")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("12-3456789", text: $taxId)
                        .onChange(of: taxId) { _, _ in hasChanges = true }
                }
            }
            .opacity(optionalSectionOpacity)
            
            // Business Address Section
            Section("Business Address") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Street Address")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("123 Main Street", text: $address)
                        .textInputAutocapitalization(.words)
                        .onChange(of: address) { _, _ in hasChanges = true }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("City")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("City", text: $city)
                        .textInputAutocapitalization(.words)
                        .onChange(of: city) { _, _ in hasChanges = true }
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("State")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("State", text: $state)
                            .textInputAutocapitalization(.characters)
                            .onChange(of: state) { _, _ in hasChanges = true }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ZIP")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("12345", text: $zipCode)
                            .keyboardType(.numberPad)
                            .onChange(of: zipCode) { _, _ in hasChanges = true }
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Country")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("United States", text: $country)
                        .textInputAutocapitalization(.words)
                        .onChange(of: country) { _, _ in hasChanges = true }
                }
            }
            .opacity(addressSectionOpacity)
            
            // Footer
            Section {
                HStack {
                    Spacer()
                    
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
                        Text("This information will appear on all invoices you create")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Spacer()
                }
            }
            .opacity(footerOpacity)
        }
        .navigationTitle("Business Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
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
    
    // MARK: - Animations
    
    private func animateEntrance() {
        // Header animation
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            headerScale = 1.0
            headerOpacity = 1.0
        }
        
        // Staggered section reveals
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
        profile = BusinessProfileService.shared.fetchProfile(context: modelContext)
        
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
        }
        
        hasChanges = false
    }
    
    private func saveProfile() {
        // Validate with haptic feedback
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
        
        // Button press animation
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            saveButtonPressed = true
        }
        
        isSaving = true
        
        // Processing haptic
        HapticService.play(.heavy)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                saveButtonPressed = false
            }
        }
        
        #if DEBUG
        print("🔵 Starting Business Profile save...")
        print("✅ Validation passed")
        print("📝 Business Name: \(trimmedBusinessName)")
        print("📧 Email: \(trimmedEmail)")
        #endif
        
        if let existingProfile = profile {
            #if DEBUG
            print("🔄 Updating existing profile (ID: \(existingProfile.id))")
            #endif
            
            // Update existing profile
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
            existingProfile.updateModifiedDate()
            
            performSave()
            
        } else {
            #if DEBUG
            print("📝 Creating NEW profile")
            #endif
            
            // Create new profile
            let newProfile = BusinessProfile(
                businessName: trimmedBusinessName,
                email: trimmedEmail,
                contactName: contactName.isEmpty ? nil : contactName,
                phone: phone.isEmpty ? nil : phone,
                address: address.isEmpty ? nil : address,
                city: city.isEmpty ? nil : city,
                state: state.isEmpty ? nil : state,
                zipCode: zipCode.isEmpty ? nil : zipCode,
                country: country.isEmpty ? nil : country,
                website: website.isEmpty ? nil : website,
                taxId: taxId.isEmpty ? nil : taxId
            )
            
            #if DEBUG
            print("📦 Profile object created (ID: \(newProfile.id))")
            print("📝 Inserting into ModelContext...")
            #endif
            
            modelContext.insert(newProfile)
            profile = newProfile
            
            performSave()
        }
    }
    
    private func performSave() {
        do {
            try modelContext.save()
            
            #if DEBUG
            print("✅ SAVE SUCCESS - Profile updated")
            #endif
            
            // Success haptic
            HapticService.shared.success()
            
            // Show saved check animation
            withAnimation(FLOAnimation.quick) {
                showSavedCheck = true
            }
            
            hasChanges = false
            isSaving = false
            
            // Dismiss after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(FLOAnimation.quickEase) {
                    showSavedCheck = false
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showingSaveConfirmation = true
                }
            }
            
        } catch {
            #if DEBUG
            print("❌ SAVE FAILED: \(error.localizedDescription)")
            print("📝 Error details: \(error)")
            #endif
            
            HapticService.shared.error()
            
            isSaving = false
            errorMessage = "Failed to save profile: \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }
}

#Preview {
    NavigationStack {
        BusinessProfileSettingsView()
            .modelContainer(for: [BusinessProfile.self])
    }
}

#Preview("With Existing Profile") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: BusinessProfile.self,
        configurations: config
    )
    
    let profile = BusinessProfile(
        businessName: "Acme Consulting",
        email: "hello@acme.com",
        contactName: "John Doe",
        phone: "(555) 123-4567",
        address: "123 Main Street",
        city: "San Francisco",
        state: "CA",
        zipCode: "94102",
        country: "United States",
        website: "www.acme.com",
        taxId: "12-3456789"
    )
    container.mainContext.insert(profile)
    
    return NavigationStack {
        BusinessProfileSettingsView()
    }
    .modelContainer(container)
}
