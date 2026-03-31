//  ProfileCardComponents.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 — Shared card-based form components for profile screens.
//  Replaces macOS Form layout (which has inconsistent spacing/alignment)
//  with custom ScrollView + VStack + card sections.
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI

// MARK: - Profile Header Card

/// Branded header with avatar circle, title, and subtitle.
/// Used at the top of both Personal Profile and Business Profile screens.
struct ProfileHeaderCard: View {
    let icon: String        // SF Symbol or initials
    let title: String
    let subtitle: String
    var color: Color = .brandPrimary
    var isInitials: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 56, height: 56)

                if isInitials {
                    Text(icon)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                } else {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title2.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.floSystemGroupedSectionBackground)
        .cornerRadius(12)
    }
}

// MARK: - Profile Section Card

/// Groups related form fields in a styled card with a section title.
struct ProfileSectionCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                content()
            }
            .padding(.bottom, 8)
        }
        .background(Color.floSystemGroupedSectionBackground)
        .cornerRadius(12)
    }
}

// MARK: - Profile Text Field Row

/// Single form field with label above, styled TextField below, optional validation checkmark.
struct ProfileFieldRow: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isValid: Bool? = nil
    var isRequired: Bool = false
    var keyboardType: ProfileKeyboardType = .default
    var capitalize: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if isRequired {
                    Text("*")
                        .font(.caption.bold())
                        .foregroundStyle(Color.expenseRed)
                }

                if let valid = isValid, valid {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.incomeGreen)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.body)
                .padding(10)
                .background(Color.floSurface.opacity(0.3))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(fieldBorderColor, lineWidth: 1)
                )
                #if os(iOS)
                .autocapitalization(capitalize ? .words : .none)
                #endif
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .animation(.easeInOut(duration: 0.2), value: isValid)
    }

    private var fieldBorderColor: Color {
        if let valid = isValid {
            return valid ? Color.incomeGreen.opacity(0.3) : Color.expenseRed.opacity(0.3)
        }
        return Color.gray.opacity(0.2)
    }
}

enum ProfileKeyboardType {
    case `default`, email, phone, url, number
}

// MARK: - Profile Read-Only Row

/// Non-editable display row with label and value.
struct ProfileDisplayRow: View {
    let label: String
    let value: String
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(Color.brandPrimary)
                }

                Text(value)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.floSurface.opacity(0.15))
            .cornerRadius(8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

// MARK: - Profile Footer Note

/// Small privacy/info note at the bottom of profile screens.
struct ProfileFooterNote: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color.brandPrimary)

            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brandPrimary.opacity(0.06))
        .cornerRadius(10)
    }
}

// MARK: - Inline HStack Fields (State + ZIP style)

struct ProfileFieldRowPair: View {
    let label1: String
    let placeholder1: String
    @Binding var text1: String
    let label2: String
    let placeholder2: String
    @Binding var text2: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(label1)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(placeholder1, text: $text1)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .padding(10)
                    .background(Color.floSurface.opacity(0.3))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(label2)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(placeholder2, text: $text2)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .padding(10)
                    .background(Color.floSurface.opacity(0.3))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

// MARK: - Toggle Row

/// Styled toggle row for settings sections.
struct ProfileToggleRow: View {
    let icon: String
    let label: String
    @Binding var isOn: Bool
    var subtitle: String? = nil
    var iconColor: Color = .brandPrimary

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(iconColor)
                .frame(width: 24, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.body)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color.brandPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Navigation Row

/// Styled navigation link row for settings sections.
struct ProfileNavigationRow<Destination: View>: View {
    let icon: String
    let label: String
    var value: String? = nil
    var iconColor: Color = .brandPrimary
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(iconColor)
                    .frame(width: 24, alignment: .center)

                Text(label)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer()

                if let value {
                    Text(value)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Action Button Row

/// Styled button row for destructive or action items.
struct ProfileActionRow: View {
    let icon: String
    let label: String
    var style: ActionStyle = .normal
    let action: () -> Void

    enum ActionStyle {
        case normal, destructive, branded
    }

    private var color: Color {
        switch style {
        case .normal: return .primary
        case .destructive: return Color.expenseRed
        case .branded: return Color.brandPrimary
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(color)
                    .frame(width: 24, alignment: .center)

                Text(label)
                    .font(.body)
                    .foregroundStyle(color)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Info Row

/// Read-only info row with icon, label, and value.
struct ProfileInfoRow: View {
    let icon: String
    let label: String
    let value: String
    var iconColor: Color = .brandPrimary

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(iconColor)
                .frame(width: 24, alignment: .center)

            Text(label)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}
