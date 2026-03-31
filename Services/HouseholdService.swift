//  HouseholdService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Household Sharing Foundation
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE:
//  Manages household creation, member management, and transaction sharing.
//  Build 8 scope is local-only — the data structures are designed for
//  future CloudKit CKShare integration.
//
//  FEATURES v1.0:
//  ✅ Household creation with owner auto-enrollment
//  ✅ Invite code generation (6-char, 24-hour expiry)
//  ✅ Member add/remove/role management
//  ✅ Transaction sharing (mark as shared/private)
//  ✅ Current household state loading on app launch
//  ✅ Thread-safe singleton matching FLO service pattern
//  ✅ Pro-only feature gating
//
//  CHANGES v1.1 - Join Household Flow:
//  ✅ Join household with invite code validation
//  ✅ HouseholdJoinError enum with localized descriptions
//  ✅ Invite code lookup across local SwiftData store
//  ✅ Auto-activate joining member for local-only Build 8

import Foundation
import SwiftData
import OSLog

// MARK: - Household Join Errors

/// Errors that can occur when joining a household via invite code.
enum HouseholdJoinError: LocalizedError {
    case invalidCode
    case codeExpired
    case codeRevoked
    case alreadyInHousehold
    case householdNotFound
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidCode:
            return "Invalid invite code. Please check and try again."
        case .codeExpired:
            return "This invite code has expired. Ask the household owner for a new code."
        case .codeRevoked:
            return "This invite code has been revoked. Ask the household owner for a new code."
        case .alreadyInHousehold:
            return "You're already in a household. Leave your current household first."
        case .householdNotFound:
            return "No household found with this invite code."
        case .saveFailed(let error):
            return "Failed to join household: \(error.localizedDescription)"
        }
    }
}

// MARK: - Household Service

@MainActor
final class HouseholdService: ObservableObject {

    // MARK: - Singleton

    static let shared = HouseholdService()
    private init() {}

    private let logger = Logger(
        subsystem: "com.finchandpoppy.flo",
        category: "Household"
    )

    // MARK: - Published State

    /// The current user's household (nil if not in one)
    @Published private(set) var currentHousehold: Household?

    /// The current user's membership record
    @Published private(set) var currentMembership: HouseholdMember?

    // MARK: - Household Management

    /// Create a new household. The current user becomes the owner.
    /// - Parameters:
    ///   - name: Display name for the household
    ///   - ownerName: Owner's display name
    ///   - ownerEmail: Owner's email address
    ///   - context: ModelContext for saving
    /// - Returns: The created Household
    @discardableResult
    func createHousehold(
        name: String,
        ownerName: String,
        ownerEmail: String,
        in context: ModelContext
    ) -> Household {
        let ownerUserID = getCurrentUserID()

        let household = Household(
            name: name,
            ownerUserID: ownerUserID
        )

        let ownerMember = HouseholdMember(
            displayName: ownerName,
            email: ownerEmail,
            role: .owner,
            status: .active
        )
        ownerMember.userID = ownerUserID
        ownerMember.household = household
        if household.members != nil {
            household.members?.append(ownerMember)
        } else {
            household.members = [ownerMember]
        }

        context.insert(household)
        context.insert(ownerMember)

        do {
            try context.save()
            currentHousehold = household
            currentMembership = ownerMember
            logger.info("Created household '\(name)' with owner '\(ownerName)'")
        } catch {
            logger.error("Failed to create household: \(error.localizedDescription)")
        }

        return household
    }

    /// Generate a shareable invite code for the household.
    /// - Returns: The generated invite code, or nil on failure
    func generateInviteCode(for household: Household, in context: ModelContext) -> String? {
        household.generateInviteCode()

        do {
            try context.save()
            logger.info("Generated invite code for household '\(household.name)'")
            return household.inviteCode
        } catch {
            logger.error("Failed to save invite code: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Join Household

    /// Join an existing household using an invite code.
    /// Validates the code, finds the household, and creates a member record.
    /// - Parameters:
    ///   - inviteCode: The 6-character invite code (with or without dash)
    ///   - memberName: Display name for the joining member
    ///   - memberEmail: Email address for the joining member
    ///   - context: ModelContext for saving
    /// - Returns: Result with the joined Household or a HouseholdJoinError
    @discardableResult
    func joinHousehold(
        inviteCode: String,
        memberName: String,
        memberEmail: String,
        in context: ModelContext
    ) -> Result<Household, HouseholdJoinError> {
        // Block if already in a household
        if currentHousehold != nil {
            logger.warning("User attempted to join while already in a household")
            return .failure(.alreadyInHousehold)
        }

        // Normalize the code: remove dashes, whitespace, uppercase
        let normalizedCode = inviteCode
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .uppercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate format: must be exactly 6 alphanumeric characters
        guard normalizedCode.count == 6,
              normalizedCode.allSatisfy({ $0.isLetter || $0.isNumber }) else {
            logger.warning("Invalid invite code format: '\(inviteCode)'")
            return .failure(.invalidCode)
        }

        // Look up household by invite code
        do {
            let allHouseholds = try context.fetch(FetchDescriptor<Household>())
            guard let household = allHouseholds.first(where: { $0.inviteCode == normalizedCode }) else {
                logger.warning("No household found with invite code '\(normalizedCode)'")
                return .failure(.householdNotFound)
            }

            // Validate the code hasn't expired
            guard let expiry = household.inviteCodeExpiry else {
                logger.warning("Invite code has been revoked for household '\(household.name)'")
                return .failure(.codeRevoked)
            }

            guard expiry > Date() else {
                logger.warning("Invite code expired for household '\(household.name)'")
                return .failure(.codeExpired)
            }

            // Create the member record
            let userID = getCurrentUserID()
            let member = HouseholdMember(
                displayName: memberName,
                email: memberEmail,
                role: .member,
                status: .active   // Auto-activate for local-only Build 8
            )
            member.userID = userID
            member.household = household
            if household.members != nil {
                household.members?.append(member)
            } else {
                household.members = [member]
            }

            context.insert(member)
            try context.save()

            // Update published state
            currentHousehold = household
            currentMembership = member

            logger.info("Joined household '\(household.name)' as '\(memberName)'")
            return .success(household)

        } catch {
            logger.error("Failed to join household: \(error.localizedDescription)")
            return .failure(.saveFailed(error))
        }
    }

    /// Add a member to the household.
    /// - Parameters:
    ///   - displayName: Member's display name
    ///   - email: Member's email address
    ///   - role: Role to assign (default: .member)
    ///   - household: The household to add to
    ///   - context: ModelContext for saving
    /// - Returns: The created HouseholdMember
    @discardableResult
    func addMember(
        displayName: String,
        email: String,
        role: HouseholdRole = .member,
        to household: Household,
        in context: ModelContext
    ) -> HouseholdMember {
        let member = HouseholdMember(
            displayName: displayName,
            email: email,
            role: role,
            status: .invited
        )
        member.household = household
        if household.members != nil {
            household.members?.append(member)
        } else {
            household.members = [member]
        }

        context.insert(member)

        do {
            try context.save()
            logger.info("Added member '\(displayName)' to household '\(household.name)' as \(role.displayName)")
        } catch {
            logger.error("Failed to add member: \(error.localizedDescription)")
        }

        return member
    }

    /// Activate a member (change from invited to active).
    func activateMember(_ member: HouseholdMember, in context: ModelContext) {
        member.status = .active

        do {
            try context.save()
            logger.info("Activated member '\(member.displayName)'")
        } catch {
            logger.error("Failed to activate member: \(error.localizedDescription)")
        }
    }

    /// Remove a member from the household.
    func removeMember(
        _ member: HouseholdMember,
        from household: Household,
        in context: ModelContext
    ) {
        guard member.role != .owner else {
            logger.warning("Cannot remove the household owner")
            return
        }

        member.status = .removed

        do {
            try context.save()
            logger.info("Removed member '\(member.displayName)' from household '\(household.name)'")
        } catch {
            logger.error("Failed to remove member: \(error.localizedDescription)")
        }
    }

    /// Update a member's role.
    func updateMemberRole(
        _ member: HouseholdMember,
        to newRole: HouseholdRole,
        in context: ModelContext
    ) {
        guard member.role != .owner else {
            logger.warning("Cannot change the owner's role")
            return
        }

        guard newRole != .owner else {
            logger.warning("Cannot assign owner role — use transferOwnership instead")
            return
        }

        member.role = newRole

        do {
            try context.save()
            logger.info("Updated '\(member.displayName)' role to \(newRole.displayName)")
        } catch {
            logger.error("Failed to update member role: \(error.localizedDescription)")
        }
    }

    /// Leave the current household (non-owner members only).
    func leaveHousehold(in context: ModelContext) {
        guard let membership = currentMembership else {
            logger.warning("Not in a household")
            return
        }

        guard membership.role != .owner else {
            logger.warning("Owner cannot leave — delete the household instead")
            return
        }

        membership.status = .removed

        do {
            try context.save()
            currentHousehold = nil
            currentMembership = nil
            logger.info("Left household")
        } catch {
            logger.error("Failed to leave household: \(error.localizedDescription)")
        }
    }

    /// Delete the household entirely (owner only).
    func deleteHousehold(_ household: Household, in context: ModelContext) {
        guard household.ownerUserID == getCurrentUserID() else {
            logger.warning("Only the owner can delete the household")
            return
        }

        context.delete(household)

        do {
            try context.save()
            currentHousehold = nil
            currentMembership = nil
            logger.info("Deleted household '\(household.name)'")
        } catch {
            logger.error("Failed to delete household: \(error.localizedDescription)")
        }
    }

    // MARK: - Transaction Sharing

    /// Mark a transaction as shared with the household.
    func shareTransaction(
        _ transaction: Transaction,
        with household: Household,
        in context: ModelContext
    ) {
        transaction.isShared = true
        transaction.householdId = household.id
        transaction.touch()

        do {
            try context.save()
            logger.info("Shared transaction '\(transaction.displayName)' with household '\(household.name)'")
        } catch {
            logger.error("Failed to share transaction: \(error.localizedDescription)")
        }
    }

    /// Make a transaction private again.
    func unshareTransaction(
        _ transaction: Transaction,
        in context: ModelContext
    ) {
        transaction.isShared = false
        transaction.householdId = nil
        transaction.touch()

        do {
            try context.save()
            logger.info("Unshared transaction '\(transaction.displayName)'")
        } catch {
            logger.error("Failed to unshare transaction: \(error.localizedDescription)")
        }
    }

    // MARK: - State Loading

    /// Load the current user's household on app launch.
    func loadCurrentHousehold(in container: ModelContainer) async {
        let context = ModelContext(container)
        let userID = getCurrentUserID()

        do {
            let memberDescriptor = FetchDescriptor<HouseholdMember>(
                predicate: #Predicate<HouseholdMember> { member in
                    member.userID == userID && member.statusRaw == "active"
                }
            )

            if let member = try context.fetch(memberDescriptor).first,
               let household = member.household {
                currentHousehold = household
                currentMembership = member
                logger.info("Loaded household '\(household.name)' for current user")
            } else {
                currentHousehold = nil
                currentMembership = nil
                logger.info("No household found for current user")
            }
        } catch {
            logger.error("Failed to load household: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    /// Get the current user's stable ID.
    /// Prefers Apple Sign In user identifier (stable across devices).
    /// Falls back to locally-generated UUID for unsigned users.
    private func getCurrentUserID() -> String {
        let key = "household.localUserID"

        // Prefer Apple Sign In user identifier (stable, cross-device)
        if let appleUserID = AppleAuthService.shared.userIdentifier {
            let existingLocalID = UserDefaults.standard.string(forKey: key)

            if let existingLocalID, existingLocalID != appleUserID {
                // First sign-in with Apple after using local UUID — migrate
                #if DEBUG
                print("[Household] Migrating user ID from local UUID to Apple ID")
                #endif
                UserDefaults.standard.set(appleUserID, forKey: key)
            } else if existingLocalID == nil {
                UserDefaults.standard.set(appleUserID, forKey: key)
            }

            return appleUserID
        }

        // Fallback: local UUID (existing behavior for unsigned users)
        if let existingID = UserDefaults.standard.string(forKey: key) {
            return existingID
        }
        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: key)
        return newID
    }

    /// Whether the current user is in a household
    var isInHousehold: Bool {
        currentHousehold != nil
    }

    /// Whether the current user can manage members
    var canManageMembers: Bool {
        currentMembership?.role.canManageMembers ?? false
    }

    /// Whether the current user can delete the household
    var canDeleteHousehold: Bool {
        currentMembership?.role.canDeleteHousehold ?? false
    }
}
