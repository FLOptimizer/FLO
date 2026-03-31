//  AssistantSuggestedQuestions.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 — Suggested question chips for My Assistant.
//  Tax-season focused defaults help users get started.
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI

struct AssistantSuggestedQuestions: View {
    let onSelect: (String) -> Void

    private let questions = [
        "Give me a financial health check",
        "What were my business expenses in 2025?",
        "How much self-employment tax do I owe?",
        "Show my monthly spending trends",
        "What are my biggest expenses?",
        "Am I over budget this month?",
        "Can I afford a new car?",
        "How should I pay off my debt?",
        "Do I have any unpaid invoices?",
        "What's my savings rate?",
        "Help me prepare for Schedule C",
        "Show my mileage deduction for 2025"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggested Questions")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            FlowLayout(spacing: 8) {
                ForEach(questions, id: \.self) { question in
                    Button {
                        onSelect(question)
                    } label: {
                        Text(question)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.brandPrimary.opacity(0.1))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.brandPrimary.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
    }
}

// MARK: - Flow Layout (wrapping horizontal layout)

/// A simple wrapping horizontal layout for question chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: ProposedViewSize(width: bounds.width, height: nil), subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}
