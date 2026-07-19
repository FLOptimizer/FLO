//  AddBusinessOnboardingView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Guided Business Setup
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Shown after migration or when user adds a new business.
//  Guides through: business name, type, first account creation.
//

import SwiftUI
import FLODesignSystem
import SwiftData

struct AddBusinessOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<BusinessProfile> { $0.isActive }, sort: \BusinessProfile.sortOrder)
    private var existingBusinesses: [BusinessProfile]

    // Step tracking
    @State private var currentStep: OnboardingStep = .businessInfo
    @State private var viewAppeared = false

    // Business info
    @State private var businessName = ""
    @State private var email = ""
    @State private var businessType: BusinessType = .soleProprietorship

    // Account creation
    @State private var createAccount = true
    @State private var accountName = ""
    @State private var accountType: AccountType = .checking

    // Result
    @State private var createdBusiness: BusinessProfile?
    @State private var showingSuccess = false

    @Query(sort: \Account.name) private var allAccounts: [Account]
    @State private var accountsToAssign: Set<UUID> = []

    enum OnboardingStep: Int, CaseIterable {
        case businessInfo
        case accountSetup
        case review
        case assignAccounts
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 16) {
                        switch currentStep {
                        case .businessInfo:
                            businessInfoStep
                        case .accountSetup:
                            accountSetupStep
                        case .review:
                            reviewStep
                        case .assignAccounts:
                            assignAccountsStep
                        }
                    }
                    .padding(16)
                }

                bottomBar
                    .padding(16)
            }
            .navigationTitle("Add a Business")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.3)) {
                    viewAppeared = true
                }
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                RoundedRectangle(cornerRadius: 2)
                    .fill(step.rawValue <= currentStep.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(height: 4)
            }
        }
    }

    // MARK: - Step 1: Business Info

    private var businessInfoStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Tell us about your business")
                    .font(.title2.weight(.bold))
                Text("This helps FLO track income, expenses, and taxes separately for each entity.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Business Name")
                        .font(.subheadline.weight(.medium))
                    TextField("e.g., Anderson Farm", text: $businessName)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Email")
                        .font(.subheadline.weight(.medium))
                    TextField("business@example.com", text: $email)
                        .textFieldStyle(.roundedBorder)
                        #if !os(macOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        #endif
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Business Type")
                        .font(.subheadline.weight(.medium))

                    ForEach(BusinessType.allCases, id: \.self) { type in
                        Button {
                            businessType = type
                        } label: {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(spacing: 12) {
                                    Image(systemName: type.defaultIcon)
                                        .font(.title3)
                                        .frame(width: 32)
                                        .foregroundStyle(businessType == type ? .white : .primary)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(type.displayName)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(businessType == type ? .white : .primary)
                                        Text("Tax form: \(type.taxFormName)")
                                            .font(.caption)
                                            .foregroundStyle(businessType == type ? .white.opacity(0.8) : .secondary)
                                    }

                                    Spacer()

                                    if businessType == type {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.white)
                                    }
                                }
                                if businessType == type {
                                    Text(type.taxImplications)
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.7))
                                        .fixedSize(horizontal: false, vertical: true)
                                        .padding(.top, 4)
                                }
                            }
                            .padding(12)
                            .background(businessType == type ? Color.accentColor : Color.floSecondarySystemBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .opacity(viewAppeared ? 1 : 0)
    }

    // MARK: - Step 2: Account Setup

    private var accountSetupStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Set up a bank account")
                    .font(.title2.weight(.bold))
                Text("Create a dedicated account to track this business's money.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Toggle(isOn: $createAccount) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Create a bank account")
                        .font(.subheadline.weight(.medium))
                    Text("You can also assign existing accounts later")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.accentColor)

            if createAccount {
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Account Name")
                            .font(.subheadline.weight(.medium))
                        TextField("e.g., Farm Checking", text: $accountName)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Account Type")
                            .font(.subheadline.weight(.medium))
                        Picker("Type", selection: $accountType) {
                            Text("Checking").tag(AccountType.checking)
                            Text("Savings").tag(AccountType.savings)
                            Text("Cash").tag(AccountType.cash)
                            Text("Other").tag(AccountType.other)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if businessType == .farm {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.orange)
                    Text("Tip: Even pre-revenue farms need a dedicated account to track equipment purchases and deductible expenses.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Step 3: Review

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Review & Create")
                    .font(.title2.weight(.bold))
                Text("Here's what we'll set up for you.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Business summary
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: businessType.defaultIcon)
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 44, height: 44)
                        .background(Color.blue.opacity(0.15))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(businessName)
                            .font(.headline)
                        Text("\(businessType.displayName) - \(businessType.taxFormName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                ReviewRow(icon: "envelope.fill", label: "Email", value: email)

                if businessType.hasSelfEmploymentTax {
                    ReviewRow(icon: "dollarsign.circle", label: "SE Tax", value: "Applicable")
                } else {
                    ReviewRow(icon: "dollarsign.circle", label: "SE Tax", value: "Not applicable")
                }

                if createAccount && !accountName.isEmpty {
                    ReviewRow(icon: "banknote", label: "Account", value: "\(accountName) (\(accountType.displayName))")
                }

                ReviewRow(icon: "doc.text", label: "Tax Settings", value: "Auto-created")
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if showingSuccess {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Business created successfully!")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.green)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            if currentStep != .businessInfo && currentStep != .assignAccounts {
                Button("Back") {
                    withAnimation {
                        currentStep = OnboardingStep(rawValue: currentStep.rawValue - 1) ?? .businessInfo
                    }
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            if currentStep == .review {
                Button {
                    createBusiness()
                } label: {
                    Text("Create Business")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .disabled(showingSuccess)
            } else if currentStep == .assignAccounts {
                Button("Skip") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button {
                    assignSelectedAccounts()
                } label: {
                    Text("Assign \(accountsToAssign.count) Account\(accountsToAssign.count == 1 ? "" : "s")")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .disabled(accountsToAssign.isEmpty)
            } else {
                Button {
                    withAnimation {
                        advanceStep()
                    }
                } label: {
                    Text("Continue")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canAdvance)
            }
        }
    }

    // MARK: - Logic

    private var canAdvance: Bool {
        switch currentStep {
        case .businessInfo:
            return !businessName.trimmingCharacters(in: .whitespaces).isEmpty &&
                   !email.trimmingCharacters(in: .whitespaces).isEmpty &&
                   email.contains("@")
        case .accountSetup:
            return !createAccount || !accountName.trimmingCharacters(in: .whitespaces).isEmpty
        case .review, .assignAccounts:
            return true
        }
    }

    private func advanceStep() {
        guard let next = OnboardingStep(rawValue: currentStep.rawValue + 1) else { return }

        // Auto-fill account name if empty
        if currentStep == .businessInfo && accountName.isEmpty {
            accountName = "\(businessName) Checking"
        }

        currentStep = next
    }

    private func createBusiness() {
        let trimmedName = businessName.trimmingCharacters(in: .whitespaces)
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)

        let business = BusinessProfileService.shared.createProfile(
            businessName: trimmedName,
            email: trimmedEmail,
            businessType: businessType,
            context: modelContext
        )
        createdBusiness = business

        // Create account if requested
        if createAccount && !accountName.trimmingCharacters(in: .whitespaces).isEmpty {
            let account = Account(
                name: accountName.trimmingCharacters(in: .whitespaces),
                accountType: accountType,
                financeType: .business
            )
            account.businessProfile = business
            modelContext.insert(account)
            try? modelContext.save()
        }

        HapticService.shared.success()

        // Check for unassigned business accounts to offer assignment
        let unassigned = allAccounts.filter { $0.businessProfile == nil && $0.financeType == .business }
        if !unassigned.isEmpty {
            withAnimation {
                currentStep = .assignAccounts
            }
        } else {
            withAnimation {
                showingSuccess = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        }
    }

    // MARK: - Step 4: Assign Existing Accounts

    /// Unassigned business accounts eligible for assignment
    private var unassignedBusinessAccounts: [Account] {
        allAccounts.filter { $0.businessProfile == nil && $0.financeType == .business }
    }

    private var assignAccountsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Assign Existing Accounts")
                    .font(.title2.weight(.bold))
                Text("Link your existing business accounts to \(createdBusiness?.businessName ?? "this business") for accurate P&L reporting.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if unassignedBusinessAccounts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.green)
                    Text("All business accounts are assigned")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(unassignedBusinessAccounts) { account in
                        Button {
                            if accountsToAssign.contains(account.id) {
                                accountsToAssign.remove(account.id)
                            } else {
                                accountsToAssign.insert(account.id)
                            }
                            HapticService.play(.selection)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: accountsToAssign.contains(account.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(accountsToAssign.contains(account.id) ? Color.brandPrimary : .secondary)
                                    .font(.title3)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(account.name)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Text(account.accountType.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }
                            .padding(12)
                            .background(accountsToAssign.contains(account.id) ? Color.brandPrimary.opacity(0.06) : Color.floSecondarySystemBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func assignSelectedAccounts() {
        guard let business = createdBusiness else { return }
        let toAssign = allAccounts.filter { accountsToAssign.contains($0.id) }
        for account in toAssign {
            account.businessProfile = business
        }
        try? modelContext.save()
        HapticService.shared.success()
        dismiss()
    }
}

// MARK: - Review Row Helper

private struct ReviewRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
        }
    }
}

// MARK: - Preview

#Preview {
    AddBusinessOnboardingView()
        .modelContainer(ModelContainer.preview())
}
