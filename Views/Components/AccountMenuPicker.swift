//  AccountMenuPicker.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Menu-based account selection
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Replaces the horizontal account-chip scrollers: with more than a few
//  accounts, chips force sideways scrolling and hide the selection. A native
//  menu picker shows every account in one vertical, scrollable list with a
//  checkmark on the current choice.
//

import SwiftUI

struct AccountMenuPicker: View {
    let title: String
    /// Caller supplies filtered/sorted accounts (e.g. matching financeType first)
    let accounts: [Account]
    @Binding var selection: Account?
    /// Adds a nil choice (e.g. "No Account", "All Accounts")
    var includeNone: Bool = false
    var noneLabel: String = "No Account"
    var showBalance: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker(title, selection: $selection) {
                if includeNone {
                    Label(noneLabel, systemImage: "circle.slash")
                        .tag(nil as Account?)
                }
                ForEach(accounts) { account in
                    Label(account.displayNameWithDigits, systemImage: account.icon)
                        .tag(Optional(account))
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selection) { _, _ in
                HapticService.play(.light)
            }
            .accessibilityLabel("\(title): \(selection?.displayNameWithDigits ?? noneLabel)")
            .accessibilityHint("Double tap to choose from \(accounts.count) accounts")

            if showBalance, let account = selection {
                HStack(spacing: 6) {
                    Text(account.financeType == .business ? "Business" : "Personal")
                    Text("·")
                        .accessibilityHidden(true)
                    Text(account.currentBalance, format: .currency(code: "USD"))
                        .foregroundStyle(account.currentBalance >= 0 ? Color.secondary : Color.red)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
            }
        }
    }
}
