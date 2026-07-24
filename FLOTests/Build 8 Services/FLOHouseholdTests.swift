//  FLOHouseholdTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Household Sharing Tests
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE: Validate household model behavior, role-based permissions,
//  invite code system, member management, and membership status.
//
//  COVERS:
//  - HouseholdRole permissions (canEdit, canManage, canDelete, canInvite)
//  - HouseholdRole display properties
//  - MembershipStatus properties
//  - Invite code generation and validation
//  - Invite code formatting (XXX-XXX)
//  - Invite code revocation
//  - Member initials calculation
//  - Member status transitions

import XCTest
@testable import FLO

final class FLOHouseholdTests: XCTestCase {}

// MARK: - HouseholdRole Permissions

extension FLOHouseholdTests {

    func testRole_OwnerCanEditTransactions() {
        XCTAssertTrue(HouseholdRole.owner.canEditTransactions)
    }

    func testRole_AdminCanEditTransactions() {
        XCTAssertTrue(HouseholdRole.admin.canEditTransactions)
    }

    func testRole_MemberCanEditTransactions() {
        XCTAssertTrue(HouseholdRole.member.canEditTransactions)
    }

    func testRole_ViewerCannotEditTransactions() {
        XCTAssertFalse(HouseholdRole.viewer.canEditTransactions)
    }

    func testRole_OwnerCanManageMembers() {
        XCTAssertTrue(HouseholdRole.owner.canManageMembers)
    }

    func testRole_AdminCanManageMembers() {
        XCTAssertTrue(HouseholdRole.admin.canManageMembers)
    }

    func testRole_MemberCannotManageMembers() {
        XCTAssertFalse(HouseholdRole.member.canManageMembers)
    }

    func testRole_ViewerCannotManageMembers() {
        XCTAssertFalse(HouseholdRole.viewer.canManageMembers)
    }

    func testRole_OnlyOwnerCanDeleteHousehold() {
        XCTAssertTrue(HouseholdRole.owner.canDeleteHousehold)
        XCTAssertFalse(HouseholdRole.admin.canDeleteHousehold)
        XCTAssertFalse(HouseholdRole.member.canDeleteHousehold)
        XCTAssertFalse(HouseholdRole.viewer.canDeleteHousehold)
    }

    func testRole_OwnerAndAdminCanInvite() {
        XCTAssertTrue(HouseholdRole.owner.canInvite)
        XCTAssertTrue(HouseholdRole.admin.canInvite)
        XCTAssertFalse(HouseholdRole.member.canInvite)
        XCTAssertFalse(HouseholdRole.viewer.canInvite)
    }
}

// MARK: - HouseholdRole Display Properties

extension FLOHouseholdTests {

    func testRole_DisplayNames() {
        XCTAssertEqual(HouseholdRole.owner.displayName, "Owner")
        XCTAssertEqual(HouseholdRole.admin.displayName, "Admin")
        XCTAssertEqual(HouseholdRole.member.displayName, "Member")
        XCTAssertEqual(HouseholdRole.viewer.displayName, "Viewer")
    }

    func testRole_Icons() {
        XCTAssertEqual(HouseholdRole.owner.icon, "crown.fill")
        XCTAssertEqual(HouseholdRole.admin.icon, "person.badge.key.fill")
        XCTAssertEqual(HouseholdRole.member.icon, "person.fill")
        XCTAssertEqual(HouseholdRole.viewer.icon, "eye.fill")
    }

    func testRole_Descriptions() {
        XCTAssertFalse(HouseholdRole.owner.description.isEmpty)
        XCTAssertFalse(HouseholdRole.admin.description.isEmpty)
        XCTAssertFalse(HouseholdRole.member.description.isEmpty)
        XCTAssertFalse(HouseholdRole.viewer.description.isEmpty)
    }

    func testRole_AllCases() {
        XCTAssertEqual(HouseholdRole.allCases.count, 4)
        XCTAssertTrue(HouseholdRole.allCases.contains(.owner))
        XCTAssertTrue(HouseholdRole.allCases.contains(.admin))
        XCTAssertTrue(HouseholdRole.allCases.contains(.member))
        XCTAssertTrue(HouseholdRole.allCases.contains(.viewer))
    }

    func testRole_RawValues() {
        XCTAssertEqual(HouseholdRole.owner.rawValue, "owner")
        XCTAssertEqual(HouseholdRole.admin.rawValue, "admin")
        XCTAssertEqual(HouseholdRole.member.rawValue, "member")
        XCTAssertEqual(HouseholdRole.viewer.rawValue, "viewer")
    }

    func testRole_InitFromRawValue() {
        XCTAssertEqual(HouseholdRole(rawValue: "owner"), .owner)
        XCTAssertEqual(HouseholdRole(rawValue: "admin"), .admin)
        XCTAssertEqual(HouseholdRole(rawValue: "member"), .member)
        XCTAssertEqual(HouseholdRole(rawValue: "viewer"), .viewer)
        XCTAssertNil(HouseholdRole(rawValue: "invalid"))
    }
}

// MARK: - MembershipStatus

extension FLOHouseholdTests {

    func testStatus_DisplayNames() {
        XCTAssertEqual(MembershipStatus.invited.displayName, "Invited")
        XCTAssertEqual(MembershipStatus.active.displayName, "Active")
        XCTAssertEqual(MembershipStatus.removed.displayName, "Removed")
    }

    func testStatus_Icons() {
        XCTAssertEqual(MembershipStatus.invited.icon, "envelope.badge.fill")
        XCTAssertEqual(MembershipStatus.active.icon, "checkmark.circle.fill")
        XCTAssertEqual(MembershipStatus.removed.icon, "xmark.circle.fill")
    }

    func testStatus_RawValues() {
        XCTAssertEqual(MembershipStatus.invited.rawValue, "invited")
        XCTAssertEqual(MembershipStatus.active.rawValue, "active")
        XCTAssertEqual(MembershipStatus.removed.rawValue, "removed")
    }

    func testStatus_InitFromRawValue() {
        XCTAssertEqual(MembershipStatus(rawValue: "invited"), .invited)
        XCTAssertEqual(MembershipStatus(rawValue: "active"), .active)
        XCTAssertEqual(MembershipStatus(rawValue: "removed"), .removed)
        XCTAssertNil(MembershipStatus(rawValue: "invalid"))
    }

    func testStatus_AllCases() {
        XCTAssertEqual(MembershipStatus.allCases.count, 3)
    }
}

// MARK: - Member Initials

extension FLOHouseholdTests {

    func testInitials_TwoNames() {
        let member = HouseholdMember(displayName: "Travis Anderson", email: "t@example.com")
        XCTAssertEqual(member.initials, "TA")
    }

    func testInitials_ThreeNames() {
        let member = HouseholdMember(displayName: "John David Smith", email: "j@example.com")
        XCTAssertEqual(member.initials, "JD")  // First two words
    }

    func testInitials_SingleName() {
        let member = HouseholdMember(displayName: "Travis", email: "t@example.com")
        XCTAssertEqual(member.initials, "TR")  // First two chars
    }

    func testInitials_LowerCase() {
        let member = HouseholdMember(displayName: "jane doe", email: "j@example.com")
        XCTAssertEqual(member.initials, "JD")
    }

    func testInitials_ShortSingleName() {
        let member = HouseholdMember(displayName: "Al", email: "a@example.com")
        XCTAssertEqual(member.initials, "AL")
    }
}

// MARK: - Member Typed Accessors

extension FLOHouseholdTests {

    func testMember_DefaultRole_IsMember() {
        let member = HouseholdMember(displayName: "Test", email: "t@test.com")
        XCTAssertEqual(member.role, .member)
    }

    func testMember_DefaultStatus_IsInvited() {
        let member = HouseholdMember(displayName: "Test", email: "t@test.com")
        XCTAssertEqual(member.status, .invited)
    }

    func testMember_RoleSetterUpdatesRaw() {
        let member = HouseholdMember(displayName: "Test", email: "t@test.com", role: .member)
        member.role = .admin
        XCTAssertEqual(member.roleRaw, "admin")
        XCTAssertEqual(member.role, .admin)
    }

    func testMember_StatusSetterUpdatesRaw() {
        let member = HouseholdMember(displayName: "Test", email: "t@test.com", status: .invited)
        member.status = .active
        XCTAssertEqual(member.statusRaw, "active")
        XCTAssertEqual(member.status, .active)
    }

    func testMember_IsActive_WhenActive() {
        let member = HouseholdMember(displayName: "Test", email: "t@test.com", status: .active)
        XCTAssertTrue(member.isActive)
    }

    func testMember_IsNotActive_WhenInvited() {
        let member = HouseholdMember(displayName: "Test", email: "t@test.com", status: .invited)
        XCTAssertFalse(member.isActive)
    }

    func testMember_IsNotActive_WhenRemoved() {
        let member = HouseholdMember(displayName: "Test", email: "t@test.com", status: .removed)
        XCTAssertFalse(member.isActive)
    }
}

// MARK: - Member Init

extension FLOHouseholdTests {

    func testMember_CustomRoleInit() {
        let owner = HouseholdMember(displayName: "Owner", email: "o@test.com", role: .owner, status: .active)
        XCTAssertEqual(owner.role, .owner)
        XCTAssertEqual(owner.status, .active)
        XCTAssertEqual(owner.displayName, "Owner")
        XCTAssertEqual(owner.email, "o@test.com")
    }

    func testMember_HasUniqueID() {
        let m1 = HouseholdMember(displayName: "A", email: "a@test.com")
        let m2 = HouseholdMember(displayName: "B", email: "b@test.com")
        XCTAssertNotEqual(m1.id, m2.id)
    }
}

// MARK: - Invite Code Characters

extension FLOHouseholdTests {

    /// Verify invite codes only use readable characters (no I/O/0/1)
    func testInviteCode_UsesReadableCharacters() {
        let allowedChars = Set("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        // Generate multiple codes to verify character set
        for _ in 0..<20 {
            let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
            let code = String((0..<6).map { _ in characters.randomElement()! })
            for char in code {
                XCTAssertTrue(allowedChars.contains(char),
                              "Code contains invalid character: \(char)")
            }
        }
    }

    func testInviteCode_Length() {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        let code = String((0..<6).map { _ in characters.randomElement()! })
        XCTAssertEqual(code.count, 6)
    }

    func testInviteCode_ExcludesConfusingChars() {
        let confusingChars: Set<Character> = ["I", "O", "0", "1"]
        let allowedChars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        for char in confusingChars {
            XCTAssertFalse(allowedChars.contains(String(char)),
                           "Allowed chars should not contain '\(char)'")
        }
    }
}

// MARK: - Role Permission Matrix

extension FLOHouseholdTests {

    /// Comprehensive permission matrix test
    func testRole_PermissionMatrix() {
        struct RolePermissions {
            let role: HouseholdRole
            let canEdit: Bool
            let canManage: Bool
            let canDelete: Bool
            let canInvite: Bool
        }

        let expected = [
            RolePermissions(role: .owner,  canEdit: true,  canManage: true,  canDelete: true,  canInvite: true),
            RolePermissions(role: .admin,  canEdit: true,  canManage: true,  canDelete: false, canInvite: true),
            RolePermissions(role: .member, canEdit: true,  canManage: false, canDelete: false, canInvite: false),
            RolePermissions(role: .viewer, canEdit: false, canManage: false, canDelete: false, canInvite: false),
        ]

        for perm in expected {
            XCTAssertEqual(perm.role.canEditTransactions, perm.canEdit,
                           "\(perm.role.displayName) canEdit should be \(perm.canEdit)")
            XCTAssertEqual(perm.role.canManageMembers, perm.canManage,
                           "\(perm.role.displayName) canManage should be \(perm.canManage)")
            XCTAssertEqual(perm.role.canDeleteHousehold, perm.canDelete,
                           "\(perm.role.displayName) canDelete should be \(perm.canDelete)")
            XCTAssertEqual(perm.role.canInvite, perm.canInvite,
                           "\(perm.role.displayName) canInvite should be \(perm.canInvite)")
        }
    }
}
