//  HouseholdSettingsView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - Accessibility Audit Fixes
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE:
//  Settings view for managing household sharing. Allows users to create
//  a household, invite members, manage roles, and leave/delete.
//
//  FEATURES v1.0:
//  ✅ Create household with name input
//  ✅ View and manage members with role badges
//  ✅ Generate and share invite codes
//  ✅ Activate/remove members
//  ✅ Leave or delete household
//  ✅ VoiceOver accessibility support
//  ✅ Dynamic Type support
//
//  CHANGES v1.1 - Accessibility Audit:
//  ✅ FIXED: CreateHouseholdSheet missing screen change announcement
//  ✅ FIXED: AddMemberSheet missing screen change announcement
//  ✅ FIXED: Revoke Code button missing accessibility hint
//
//  CHANGES v1.2 - Join Household Flow:
//  ✅ "Join with Invite Code" button in no-household state
//  ✅ JoinHouseholdSheet with code input, validation, and error display
//  ✅ Real-time code formatting (auto-uppercase, dash insertion)
//  ✅ VoiceOver and Dynamic Type support for join flow

import SwiftUI
import FLODesignSystem
import SwiftData

struct HouseholdSettingsView: View {
    @Environment(\.modelContext) private var context
    @ObservedObject private var householdService = HouseholdService.shared
    @EnvironmentObject var subscriptionManager: SubscriptionManager

    @AppStorage("userName") private var userName = ""
    @AppStorage("userEmail") private var userEmail = ""

    @State private var showingCreateSheet = false
    @State private var showingJoinSheet = false
    @State private var showingAddMember = false
    @State private var showingDeleteConfirmation = false
    @State private var showingLeaveConfirmation = false
    @State private var viewAppeared = false

    var body: some View {
        List {
            if let household = householdService.currentHousehold {
                householdInfoSection(household)
                membersSection(household)
                inviteSection(household)
                actionsSection(household)
            } else {
                noHouseholdSection
            }
        }
        .navigationTitle("Household")
        .sheet(isPresented: $showingCreateSheet) {
            CreateHouseholdSheet()
        }
        .sheet(isPresented: $showingJoinSheet) {
            JoinHouseholdSheet()
        }
        .sheet(isPresented: $showingAddMember) {
            if let household = householdService.currentHousehold {
                AddMemberSheet(household: household)
            }
        }
        .onAppear {
            withAnimation(FLOAnimation.standard) {
                viewAppeared = true
            }
            AccessibilityAnnouncement.screenChanged("Household settings")
        }
    }

    // MARK: - No Household

    private var noHouseholdSection: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "person.2.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.indigo)
                    .accessibilityHidden(true)

                Text("No Household")
                    .font(.headline)

                Text("Create a new household or join an existing one with an invite code to share financial data with family members.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    HapticService.play(.medium)
                    showingCreateSheet = true
                } label: {
                    Label("Create Household", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .accessibilityHint("Opens form to create a new household for sharing finances")

                Button {
                    HapticService.play(.medium)
                    showingJoinSheet = true
                } label: {
                    Label("Join with Invite Code", systemImage: "envelope.open.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(.indigo)
                .accessibilityHint("Enter a 6-character invite code to join an existing household")
            }
            .padding(.vertical, 20)
        }
    }

    // MARK: - Household Info

    private func householdInfoSection(_ household: Household) -> some View {
        Section {
            HStack {
                Image(systemName: "house.fill")
                    .foregroundStyle(.indigo)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(household.name)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("Created \(household.createdAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)

            HStack {
                Text("Members")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(household.memberCount)")
                    .fontWeight(.medium)
            }

            if !household.pendingInvitations.isEmpty {
                HStack {
                    Text("Pending Invitations")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(household.pendingInvitations.count)")
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                }
            }
        } header: {
            Text("Household")
        }
    }

    // MARK: - Members

    private func membersSection(_ household: Household) -> some View {
        Section {
            ForEach((household.members ?? []).filter { $0.status != .removed }) { member in
                HStack(spacing: 12) {
                    // Avatar
                    Text(member.initials)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(member.role == .owner ? Color.indigo : Color.secondary)
                        .clipShape(Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(member.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(member.email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }

                    Spacer()

                    // Role badge
                    HStack(spacing: 4) {
                        Image(systemName: member.role.icon)
                            .font(.caption2)
                            .accessibilityHidden(true)
                        Text(member.role.displayName)
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(member.role == .owner ? Color.indigo.opacity(0.15) : Color.secondary.opacity(0.1))
                    .foregroundStyle(member.role == .owner ? .indigo : .secondary)
                    .cornerRadius(8)

                    // Status for invited members
                    if member.status == .invited {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .accessibilityLabel("Pending")
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(member.displayName), \(member.role.displayName), \(member.status.displayName)")
                .swipeActions(edge: .trailing) {
                    if householdService.canManageMembers && member.role != .owner {
                        Button(role: .destructive) {
                            HapticService.play(.heavy)
                            householdService.removeMember(member, from: household, in: context)
                        } label: {
                            Label("Remove", systemImage: "person.badge.minus")
                        }
                    }
                }
                .swipeActions(edge: .leading) {
                    if householdService.canManageMembers && member.status == .invited {
                        Button {
                            HapticService.play(.success)
                            householdService.activateMember(member, in: context)
                        } label: {
                            Label("Activate", systemImage: "checkmark.circle")
                        }
                        .tint(.green)
                    }
                }
            }

            if householdService.canManageMembers {
                Button {
                    HapticService.play(.medium)
                    showingAddMember = true
                } label: {
                    Label("Add Member", systemImage: "person.badge.plus")
                        .foregroundStyle(.indigo)
                }
                .accessibilityHint("Add a new member to the household")
            }
        } header: {
            Text("Members")
        }
    }

    // MARK: - Invite Code

    private func inviteSection(_ household: Household) -> some View {
        Section {
            if household.isInviteCodeValid, let code = household.formattedInviteCode {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Invite Code")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(code)
                            .font(.title2)
                            .fontWeight(.bold)
                            .fontDesign(.monospaced)
                    }

                    if let timeRemaining = household.inviteCodeTimeRemaining {
                        Text(timeRemaining)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Invite code: \(code)")

                Button {
                    HapticService.play(.medium)
                    if let code = household.inviteCode {
                        #if canImport(UIKit)
                        UIPasteboard.general.string = code
                        #else
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(code, forType: .string)
                        #endif
                        HapticService.play(.success)
                        AccessibilityAnnouncement.announce("Invite code copied")
                    }
                } label: {
                    Label("Copy Code", systemImage: "doc.on.doc")
                }

                Button(role: .destructive) {
                    HapticService.play(.light)
                    household.revokeInviteCode()
                    try? context.save()
                    AccessibilityAnnouncement.announce("Invite code revoked")
                } label: {
                    Label("Revoke Code", systemImage: "xmark.circle")
                }
                .accessibilityHint("Invalidates the current invite code so it can no longer be used")
            } else if householdService.canManageMembers {
                Button {
                    HapticService.play(.medium)
                    _ = householdService.generateInviteCode(for: household, in: context)
                    HapticService.play(.success)
                    AccessibilityAnnouncement.announce("Invite code generated")
                } label: {
                    Label("Generate Invite Code", systemImage: "qrcode")
                        .foregroundStyle(.indigo)
                }
                .accessibilityHint("Creates a 6-character code valid for 24 hours")
            }
        } header: {
            Text("Invitation")
        } footer: {
            Text("Share the invite code with family members. Codes expire after 24 hours.")
        }
    }

    // MARK: - Actions

    private func actionsSection(_ household: Household) -> some View {
        Section {
            if householdService.canDeleteHousehold {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete Household", systemImage: "trash")
                }
                .confirmationDialog(
                    "Delete Household?",
                    isPresented: $showingDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) {
                        HapticService.play(.heavy)
                        householdService.deleteHousehold(household, in: context)
                    }
                } message: {
                    Text("This will remove the household and all member data. Shared transactions will become private. This cannot be undone.")
                }
            } else {
                Button(role: .destructive) {
                    showingLeaveConfirmation = true
                } label: {
                    Label("Leave Household", systemImage: "rectangle.portrait.and.arrow.right")
                }
                .confirmationDialog(
                    "Leave Household?",
                    isPresented: $showingLeaveConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Leave", role: .destructive) {
                        HapticService.play(.heavy)
                        householdService.leaveHousehold(in: context)
                    }
                } message: {
                    Text("You will no longer see shared transactions from this household.")
                }
            }
        }
    }
}

// MARK: - Create Household Sheet

struct CreateHouseholdSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var householdService = HouseholdService.shared

    @AppStorage("userName") private var userName = ""
    @AppStorage("userEmail") private var userEmail = ""

    @State private var householdName = ""
    @State private var ownerName = ""
    @State private var ownerEmail = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Household Name", text: $householdName)
                        .textContentType(.organizationName)
                        .accessibilityLabel("Household name")
                } header: {
                    Text("Household")
                } footer: {
                    Text("Choose a name like \"Anderson Family\" or \"Our Finances\"")
                }

                Section {
                    TextField("Your Name", text: $ownerName)
                        .textContentType(.name)
                    TextField("Your Email", text: $ownerEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Your Info")
                } footer: {
                    Text("This identifies you as the household owner.")
                }
            }
            .navigationTitle("Create Household")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        HapticService.play(.success)
                        householdService.createHousehold(
                            name: householdName.trimmingCharacters(in: .whitespacesAndNewlines),
                            ownerName: ownerName.trimmingCharacters(in: .whitespacesAndNewlines),
                            ownerEmail: ownerEmail.trimmingCharacters(in: .whitespacesAndNewlines),
                            in: context
                        )
                        dismiss()
                    }
                    .disabled(householdName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || ownerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if ownerName.isEmpty { ownerName = userName }
                if ownerEmail.isEmpty { ownerEmail = userEmail }
                AccessibilityAnnouncement.screenChanged("Create household")
            }
        }
    }
}

// MARK: - Join Household Sheet

struct JoinHouseholdSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var householdService = HouseholdService.shared

    @AppStorage("userName") private var userName = ""
    @AppStorage("userEmail") private var userEmail = ""

    @State private var inviteCode = ""
    @State private var memberName = ""
    @State private var memberEmail = ""
    @State private var errorMessage: String?
    @State private var isJoining = false

    /// Formatted display of the invite code (auto-insert dash)
    private var formattedCode: String {
        let clean = inviteCode
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .uppercased()
            .prefix(6)
        if clean.count > 3 {
            return "\(clean.prefix(3))-\(clean.suffix(clean.count - 3))"
        }
        return String(clean)
    }

    private var isValid: Bool {
        let cleanCode = inviteCode
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
        return cleanCode.count == 6
            && !memberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "envelope.open.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.indigo)
                            .accessibilityHidden(true)

                        Text("Enter the 6-character invite code shared by your household owner.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)

                    TextField("Invite Code (e.g. ABC-DEF)", text: $inviteCode)
                        .font(.title2)
                        .fontWeight(.bold)
                        .fontDesign(.monospaced)
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .accessibilityLabel("Invite code")
                        .accessibilityHint("Enter the 6-character code, like A B C dash D E F")
                        .onChange(of: inviteCode) { _, newValue in
                            // Auto-format: strip to max 6 clean chars
                            let clean = newValue
                                .replacingOccurrences(of: "-", with: "")
                                .replacingOccurrences(of: " ", with: "")
                                .uppercased()
                            if clean.count > 6 {
                                inviteCode = String(clean.prefix(6))
                            }
                            // Clear error when user edits
                            if errorMessage != nil {
                                errorMessage = nil
                            }
                        }
                } header: {
                    Text("Invite Code")
                }

                Section {
                    TextField("Your Name", text: $memberName)
                        .textContentType(.name)
                    TextField("Your Email", text: $memberEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Your Info")
                } footer: {
                    Text("This identifies you within the household.")
                }

                if let errorMessage {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .accessibilityHidden(true)
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Error: \(errorMessage)")
                    }
                }
            }
            .navigationTitle("Join Household")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Join") {
                        joinHousehold()
                    }
                    .disabled(!isValid || isJoining)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if memberName.isEmpty { memberName = userName }
                if memberEmail.isEmpty { memberEmail = userEmail }
                AccessibilityAnnouncement.screenChanged("Join household")
            }
        }
    }

    private func joinHousehold() {
        isJoining = true
        HapticService.play(.medium)

        let result = householdService.joinHousehold(
            inviteCode: inviteCode,
            memberName: memberName.trimmingCharacters(in: .whitespacesAndNewlines),
            memberEmail: memberEmail.trimmingCharacters(in: .whitespacesAndNewlines),
            in: context
        )

        switch result {
        case .success(let household):
            HapticService.play(.success)
            AccessibilityAnnouncement.announce("Joined household \(household.name)")
            dismiss()
        case .failure(let error):
            HapticService.play(.error)
            errorMessage = error.errorDescription
            isJoining = false
        }
    }
}

// MARK: - Add Member Sheet

struct AddMemberSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var householdService = HouseholdService.shared

    let household: Household

    @State private var memberName = ""
    @State private var memberEmail = ""
    @State private var selectedRole: HouseholdRole = .member

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $memberName)
                        .textContentType(.name)
                    TextField("Email", text: $memberEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Member Info")
                }

                Section {
                    Picker("Role", selection: $selectedRole) {
                        ForEach(HouseholdRole.allCases.filter { $0 != .owner }) { role in
                            HStack {
                                Image(systemName: role.icon)
                                Text(role.displayName)
                            }
                            .tag(role)
                        }
                    }
                } header: {
                    Text("Permissions")
                } footer: {
                    Text(selectedRole.description)
                }
            }
            .navigationTitle("Add Member")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                AccessibilityAnnouncement.screenChanged("Add member")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        HapticService.play(.success)
                        householdService.addMember(
                            displayName: memberName.trimmingCharacters(in: .whitespacesAndNewlines),
                            email: memberEmail.trimmingCharacters(in: .whitespacesAndNewlines),
                            role: selectedRole,
                            to: household,
                            in: context
                        )
                        dismiss()
                    }
                    .disabled(memberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
