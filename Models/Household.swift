//  Household.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Household Sharing Foundation (Build 8)
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE:
//  Data models for household sharing functionality. A Household represents
//  a shared financial unit (e.g., family, couple) with multiple members
//  who can share transactions and budgets.
//
//  FEATURES v1.0:
//  ✅ Household model with invite code generation
//  ✅ HouseholdMember model with roles and status
//  ✅ Role-based permissions (owner/admin/member/viewer)
//  ✅ Invite code system (6-char alphanumeric, 24-hour expiry)
//  ✅ CloudKit-compatible design (no @Attribute(.unique), all defaults)
//  ✅ No breaking changes to existing models — purely additive
//
//  DESIGN NOTES:
//  - Build 8 scope is local-only (CloudKit sync still disabled)
//  - Invite codes are preparatory for CloudKit CKShare in future builds
//  - Raw string backing for enums ensures CloudKit compatibility
//  - All properties have defaults for lightweight migration

import Foundation
import SwiftData

// MARK: - Household Model

/// A shared financial unit (family, couple, household) that can share
/// transactions, budgets, and financial data between members.
@Model
final class Household {

    // MARK: - Identifiers

    /// Unique identifier. No @Attribute(.unique) for CloudKit compatibility.
    var id: UUID = UUID()

    // MARK: - Core Properties

    /// Display name for the household (e.g., "Anderson Family")
    var name: String = ""

    /// When the household was created
    var createdAt: Date = Date()

    /// The iCloud user record ID of the household owner.
    /// Used for CloudKit CKShare ownership when sync is enabled.
    var ownerUserID: String = ""

    /// 6-character alphanumeric invitation code for joining
    var inviteCode: String?

    /// When the invite code expires (24 hours from generation)
    var inviteCodeExpiry: Date?

    // MARK: - Relationships

    /// All members of this household (owner included)
    @Relationship(deleteRule: .cascade, inverse: \HouseholdMember.household)
    var members: [HouseholdMember]?

    // MARK: - Initialization

    init(
        name: String,
        ownerUserID: String
    ) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.ownerUserID = ownerUserID
        self.inviteCode = nil
        self.inviteCodeExpiry = nil
    }

    // MARK: - Computed Properties

    /// Members with active status
    var activeMembers: [HouseholdMember] {
        (members ?? []).filter { $0.status == .active }
    }

    /// Count of active members
    var memberCount: Int {
        activeMembers.count
    }

    /// Members with pending invitations
    var pendingInvitations: [HouseholdMember] {
        (members ?? []).filter { $0.status == .invited }
    }

    /// Whether the invite code is still valid (not expired)
    var isInviteCodeValid: Bool {
        guard let code = inviteCode, !code.isEmpty,
              let expiry = inviteCodeExpiry else { return false }
        return expiry > Date()
    }

    /// Display string for the invite code with formatting
    var formattedInviteCode: String? {
        guard let code = inviteCode, isInviteCodeValid else { return nil }
        // Format as XXX-XXX for readability
        if code.count == 6 {
            let first = code.prefix(3)
            let second = code.suffix(3)
            return "\(first)-\(second)"
        }
        return code
    }

    /// Time remaining on the invite code
    var inviteCodeTimeRemaining: String? {
        guard let expiry = inviteCodeExpiry, isInviteCodeValid else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "Expires \(formatter.localizedString(for: expiry, relativeTo: Date()))"
    }

    // MARK: - Methods

    /// Generate a new 6-character alphanumeric invite code.
    /// Uses characters that are easy to read (no I/O/0/1 for clarity).
    func generateInviteCode() {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        inviteCode = String((0..<6).map { _ in characters.randomElement()! })
        inviteCodeExpiry = Calendar.current.date(byAdding: .hour, value: 24, to: Date())
    }

    /// Invalidate the current invite code
    func revokeInviteCode() {
        inviteCode = nil
        inviteCodeExpiry = nil
    }
}

// MARK: - Protocol Conformances

extension Household: Identifiable {}

extension Household: Equatable {
    static func == (lhs: Household, rhs: Household) -> Bool {
        lhs.id == rhs.id
    }
}

extension Household: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Household Member Model

/// A member of a household with a specific role and status.
@Model
final class HouseholdMember {

    // MARK: - Identifiers

    var id: UUID = UUID()

    // MARK: - Core Properties

    /// Display name for this member
    var displayName: String = ""

    /// Email address (for identification and future CloudKit matching)
    var email: String = ""

    /// Raw string backing for role (CloudKit compatible)
    var roleRaw: String = HouseholdRole.member.rawValue

    /// When the member joined or was invited
    var joinedAt: Date = Date()

    /// Raw string backing for status (CloudKit compatible)
    var statusRaw: String = MembershipStatus.invited.rawValue

    /// The iCloud user record ID (populated when CloudKit syncs)
    var userID: String?

    // MARK: - Relationships

    /// The household this member belongs to
    @Relationship(deleteRule: .nullify)
    var household: Household?

    // MARK: - Initialization

    init(
        displayName: String,
        email: String,
        role: HouseholdRole = .member,
        status: MembershipStatus = .invited
    ) {
        self.id = UUID()
        self.displayName = displayName
        self.email = email
        self.roleRaw = role.rawValue
        self.joinedAt = Date()
        self.statusRaw = status.rawValue
        self.userID = nil
    }

    // MARK: - Typed Accessors

    /// The member's role (owner, admin, member, viewer)
    var role: HouseholdRole {
        get { HouseholdRole(rawValue: roleRaw) ?? .member }
        set { roleRaw = newValue.rawValue }
    }

    /// The member's status (invited, active, removed)
    var status: MembershipStatus {
        get { MembershipStatus(rawValue: statusRaw) ?? .invited }
        set { statusRaw = newValue.rawValue }
    }

    /// Whether this member has been accepted into the household
    var isActive: Bool {
        status == .active
    }

    /// The member's initials for avatar display
    var initials: String {
        let components = displayName.split(separator: " ")
        if components.count >= 2 {
            return "\(components[0].prefix(1))\(components[1].prefix(1))".uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }
}

// MARK: - Protocol Conformances

extension HouseholdMember: Identifiable {}

extension HouseholdMember: Equatable {
    static func == (lhs: HouseholdMember, rhs: HouseholdMember) -> Bool {
        lhs.id == rhs.id
    }
}

extension HouseholdMember: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Supporting Enums

/// Roles within a household with associated permissions.
enum HouseholdRole: String, Codable, CaseIterable, Identifiable {
    case owner = "owner"
    case admin = "admin"
    case member = "member"
    case viewer = "viewer"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .owner: return "Owner"
        case .admin: return "Admin"
        case .member: return "Member"
        case .viewer: return "Viewer"
        }
    }

    var description: String {
        switch self {
        case .owner: return "Full control, can delete household"
        case .admin: return "Can manage members and shared transactions"
        case .member: return "Can add and edit shared transactions"
        case .viewer: return "Can view shared transactions only"
        }
    }

    var icon: String {
        switch self {
        case .owner: return "crown.fill"
        case .admin: return "person.badge.key.fill"
        case .member: return "person.fill"
        case .viewer: return "eye.fill"
        }
    }

    /// Whether this role can create/edit transactions
    var canEditTransactions: Bool {
        self != .viewer
    }

    /// Whether this role can manage household members
    var canManageMembers: Bool {
        self == .owner || self == .admin
    }

    /// Whether this role can delete the household
    var canDeleteHousehold: Bool {
        self == .owner
    }

    /// Whether this role can generate invite codes
    var canInvite: Bool {
        self == .owner || self == .admin
    }
}

/// Membership status within a household.
enum MembershipStatus: String, Codable, CaseIterable {
    case invited = "invited"
    case active = "active"
    case removed = "removed"

    var displayName: String {
        switch self {
        case .invited: return "Invited"
        case .active: return "Active"
        case .removed: return "Removed"
        }
    }

    var icon: String {
        switch self {
        case .invited: return "envelope.badge.fill"
        case .active: return "checkmark.circle.fill"
        case .removed: return "xmark.circle.fill"
        }
    }
}
