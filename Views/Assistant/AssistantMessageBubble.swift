//  AssistantMessageBubble.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 — Chat message bubble for My Assistant.
//  User messages right-aligned with brand tint, assistant left-aligned.
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI

struct AssistantMessageBubble: View {
    let message: AssistantMessage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.isUser {
                Spacer(minLength: 60)
            } else {
                // Assistant avatar
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .font(.title3)
                    .foregroundStyle(Color.brandPrimary)
                    .frame(width: 32, height: 32)
                    .padding(.top, 4)
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(message.isUser
                                ? Color.brandPrimary.opacity(0.15)
                                : Color.floSystemGroupedSectionBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                message.isUser
                                    ? Color.brandPrimary.opacity(0.3)
                                    : Color.primary.opacity(0.08),
                                lineWidth: 1
                            )
                    )

                Text(DateFormatter.shortDate.string(from: message.timestamp))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if !message.isUser {
                Spacer(minLength: 60)
            } else {
                // User avatar
                Image(systemName: "person.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.brandPrimary)
                    .frame(width: 32, height: 32)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal)
    }
}
