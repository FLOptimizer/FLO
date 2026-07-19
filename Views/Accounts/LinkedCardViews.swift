//  LinkedCardViews.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - Catalyst form style · Card management UI components
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Shared views for managing LinkedCards on accounts:
//  - LinkedCardRow: displays a single card in a list
//  - AddLinkedCardSheet: form for adding a new card
//  - PendingCard: lightweight struct for queuing cards before account save

import SwiftUI
import SwiftData

// MARK: - Pending Card (for AddAccountView pre-save)

/// Lightweight value type to queue cards before the account exists in SwiftData.
struct PendingCard: Identifiable {
    let id = UUID()
    var lastFourDigits: String
    var cardholderName: String
    var nickname: String = ""
    var network: CardNetwork?
    var expirationMonth: Int?
    var expirationYear: Int?

    var expirationDisplay: String? {
        guard let month = expirationMonth, let year = expirationYear else { return nil }
        return String(format: "%02d/%02d", month, year % 100)
    }
}

// MARK: - Linked Card Row

/// Displays a LinkedCard in a list with cardholder name, last 4, network, and expiration status.
struct LinkedCardRow: View {
    let card: LinkedCard

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: card.network?.icon ?? "creditcard")
                .font(.title3)
                .foregroundStyle(card.isExpired ? .red : .secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(card.cardholderName)
                    .font(.subheadline.weight(.medium))

                HStack(spacing: 6) {
                    Text("****\(card.lastFourDigits)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    if let networkName = card.network?.displayName {
                        Text(networkName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if let exp = card.expirationDisplay {
                        Text("Exp: \(exp)")
                            .font(.caption2)
                            .foregroundStyle(card.isExpired ? .red : (card.isExpiringSoon ? .orange : .secondary))
                    }
                }

                if let nickname = card.nickname, !nickname.isEmpty {
                    Text(nickname)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if card.isExpired {
                Text("Expired")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.red.opacity(0.1))
                    .clipShape(Capsule())
            } else if card.isExpiringSoon {
                Text("Expiring")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(card.cardholderName), card ending in \(card.lastFourDigits)\(card.isExpired ? ", expired" : "")")
    }
}

// MARK: - Add Linked Card Sheet

/// Form for adding a new linked card. Works in two modes:
/// 1. Directly attached to an existing Account (EditAccountView)
/// 2. Returns a PendingCard via callback (AddAccountView)
struct AddLinkedCardSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// When set, card is saved directly to this account.
    var account: Account? = nil

    /// When set, card is returned via callback (for pre-save queuing).
    var onAdd: ((PendingCard) -> Void)? = nil

    /// Zone 3 adaptive presentation — when false, omits NavigationStack wrapper.
    var embedInNavigationStack: Bool = true

    /// Callback for Zone 3 cancel/dismiss (replaces `dismiss()` when set).
    var onCancel: (() -> Void)? = nil

    @State private var lastFourDigits = ""
    @State private var cardholderName = ""
    @State private var nickname = ""
    @State private var network: CardNetwork = .visa
    @State private var expirationMonth: Int = {
        Calendar.current.component(.month, from: Date())
    }()
    @State private var expirationYear: Int = {
        Calendar.current.component(.year, from: Date()) + 3
    }()
    @State private var trackExpiration = true

    private var isValid: Bool {
        lastFourDigits.count == 4 && !cardholderName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        let formContent = Form {
                Section("Card Details") {
                    TextField("Last 4 Digits", text: $lastFourDigits)
                        #if !os(macOS)
                        .keyboardType(.numberPad)
                        #endif
                        .onChange(of: lastFourDigits) { _, newValue in
                            lastFourDigits = String(newValue.filter(\.isNumber).prefix(4))
                        }
                        .accessibilityLabel("Last four digits of card number")

                    TextField("Cardholder Name", text: $cardholderName)
                        #if !os(macOS)
                        .textInputAutocapitalization(.words)
                        #endif
                        .accessibilityLabel("Name on card")

                    TextField("Card Nickname (Optional)", text: $nickname)
                        #if !os(macOS)
                        .textInputAutocapitalization(.words)
                        #endif
                        .accessibilityLabel("Optional card nickname")
                }

                Section("Card Network") {
                    Picker("Network", selection: $network) {
                        ForEach(CardNetwork.allCases) { net in
                            Text(net.displayName).tag(net)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    Toggle("Track Expiration", isOn: $trackExpiration)

                    if trackExpiration {
                        HStack {
                            Picker("Month", selection: $expirationMonth) {
                                ForEach(1...12, id: \.self) { month in
                                    Text(String(format: "%02d", month)).tag(month)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity)

                            Text("/")
                                .foregroundStyle(.secondary)

                            Picker("Year", selection: $expirationYear) {
                                let currentYear = Calendar.current.component(.year, from: Date())
                                ForEach(currentYear...currentYear + 10, id: \.self) { year in
                                    Text(String(year)).tag(year)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity)
                        }
                    }
                } header: {
                    Text("Expiration Date")
                } footer: {
                    if trackExpiration {
                        Text("You'll be notified when this card is about to expire.")
                    }
                }
            }
            #if os(macOS) || targetEnvironment(macCatalyst)
            .formStyle(.grouped)
            #endif
            .scrollContentBackground(.hidden)
            .navigationTitle("Add Card")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { performDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { saveCard() }
                        .disabled(!isValid)
                }
            }

        if embedInNavigationStack {
            NavigationStack { formContent }
                .floMacSheetFrame()
        } else {
            formContent
        }
    }

    private func performDismiss() {
        if let onCancel {
            onCancel()
        } else {
            dismiss()
        }
    }

    private func saveCard() {
        let expMonth = trackExpiration ? expirationMonth : nil
        let expYear = trackExpiration ? expirationYear : nil

        if let account {
            // Direct save to existing account
            let card = LinkedCard(
                lastFourDigits: lastFourDigits,
                cardholderName: cardholderName.trimmingCharacters(in: .whitespaces),
                nickname: nickname.trimmingCharacters(in: .whitespaces).isEmpty ? nil : nickname.trimmingCharacters(in: .whitespaces),
                network: network,
                expirationMonth: expMonth,
                expirationYear: expYear
            )
            card.account = account
            modelContext.insert(card)
            try? modelContext.save()
        } else if let onAdd {
            // Queue as PendingCard
            let pending = PendingCard(
                lastFourDigits: lastFourDigits,
                cardholderName: cardholderName.trimmingCharacters(in: .whitespaces),
                nickname: nickname.trimmingCharacters(in: .whitespaces),
                network: network,
                expirationMonth: expMonth,
                expirationYear: expYear
            )
            onAdd(pending)
        }

        HapticService.play(.success)
        performDismiss()
    }
}

#if DEBUG
#Preview("Add Card") {
    AddLinkedCardSheet()
        .modelContainer(for: [Account.self, LinkedCard.self], inMemory: true)
}
#endif
