//  AssistantView.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 — My Assistant main chat view (Zone 2).
//  On-device AI financial guidance using Apple Foundation Models.
//  Tax-season focused with suggested questions and data-driven responses.
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI
import SwiftData

struct AssistantView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AssistantMessage.timestamp) private var allMessages: [AssistantMessage]

    @State private var inputText = ""
    @State private var assistantService = AssistantService()
    @State private var currentConversationID = UUID()
    @State private var scrollToBottom = false

    /// Shared context that drives Zone 3 data panel
    private var assistantContext: AssistantContext { NavigationService.shared.assistantContext }

    private var messages: [AssistantMessage] {
        allMessages.filter { $0.conversationID == currentConversationID }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tax disclaimer banner
            disclaimerBanner

            // Chat messages or empty state
            ScrollViewReader { proxy in
                ScrollView {
                    if messages.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(messages) { message in
                                AssistantMessageBubble(message: message)
                                    .id(message.id)
                            }

                            if assistantService.isGenerating {
                                typingIndicator
                            }
                        }
                        .padding(.vertical)
                    }
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: scrollToBottom) { _, _ in
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Staged action awaiting user confirmation (Tier 2 guardrail)
            actionConfirmationCard

            // Input bar
            inputBar
        }
        .navigationTitle("My Assistant")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    startNewConversation()
                } label: {
                    Image(systemName: "plus.bubble")
                        .foregroundStyle(Color.brandPrimary)
                }
                .help("Start new conversation")
                .accessibilityLabel("New conversation")
            }
        }
        .task {
            assistantService.configure(modelContext: modelContext, context: assistantContext)
        }
    }

    // MARK: - Disclaimer Banner

    private var disclaimerBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Color.brandPrimary)
                .font(.caption)
            Text("Not tax advice. Consult a qualified tax professional for tax decisions.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.brandPrimary.opacity(0.06))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 16)

            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.brandPrimary.opacity(0.6))

            VStack(spacing: 8) {
                Text("My Assistant")
                    .font(.title2.bold())
                Text("Ask questions about your financial data")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Tier 3: proactive weekly digest, computed fresh from live data
            if let digest = assistantService.weeklyDigest() {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Your Week", systemImage: "calendar.badge.clock")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.brandPrimary)
                    Text(digest)
                        .font(.subheadline)
                        .lineSpacing(4)
                    Button {
                        sendMessage("Walk me through my spending this week — anything I should know?")
                    } label: {
                        Text("Discuss my week")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.brandPrimary)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.floSystemGroupedSectionBackground)
                )
                .accessibilityElement(children: .combine)
            }

            AssistantSuggestedQuestions { question in
                sendMessage(question)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Typing Indicator

    private var typingIndicator: some View {
        HStack(spacing: 12) {
            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                .font(.title3)
                .foregroundStyle(Color.brandPrimary)
                .frame(width: 32, height: 32)

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.brandPrimary.opacity(0.5))
                        .frame(width: 6, height: 6)
                        .offset(y: assistantService.isGenerating ? -4 : 0)
                        .animation(
                            .easeInOut(duration: 0.4)
                                .repeatForever()
                                .delay(Double(index) * 0.15),
                            value: assistantService.isGenerating
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.floSystemGroupedSectionBackground)
            )

            Spacer()
        }
        .padding(.horizontal)
    }

    // MARK: - Action Confirmation

    /// Card shown when the model has STAGED a change. Nothing is written
    /// until the user taps Confirm here.
    @ViewBuilder
    private var actionConfirmationCard: some View {
        if let action = assistantService.pendingAction {
            VStack(alignment: .leading, spacing: 10) {
                Label(action.summary, systemImage: "sparkles")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                HStack(spacing: 12) {
                    Button {
                        HapticService.play(.medium)
                        let result = assistantService.applyPendingAction()
                        let confirmation = AssistantMessage(
                            content: "✅ \(result)",
                            isUser: false,
                            conversationID: currentConversationID
                        )
                        modelContext.insert(confirmation)
                        HapticService.play(.success)
                        scrollToBottom.toggle()
                    } label: {
                        Text("Confirm")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.brandPrimary)
                            .clipShape(Capsule())
                    }
                    .accessibilityHint("Applies the proposed change")

                    Button("Cancel") {
                        HapticService.play(.light)
                        assistantService.cancelPendingAction()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.brandPrimary.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.brandPrimary.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Proposed change: \(action.summary). Confirm or cancel.")
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Ask about your finances...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.floSystemGroupedSectionBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .onSubmit {
                    sendMessage(inputText)
                }

            Button {
                sendMessage(inputText)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color.secondary
                            : Color.brandPrimary
                    )
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || assistantService.isGenerating)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Actions

    private func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Save user message
        let userMessage = AssistantMessage(
            content: trimmed,
            isUser: true,
            conversationID: currentConversationID
        )
        modelContext.insert(userMessage)
        inputText = ""

        // Generate response
        Task {
            // Insert the assistant message immediately and stream tokens into
            // it — answers appear as they're generated instead of after a wait
            let assistantMessage = AssistantMessage(
                content: "",
                isUser: false,
                conversationID: currentConversationID
            )
            modelContext.insert(assistantMessage)
            scrollToBottom.toggle()

            let response = await assistantService.generateResponse(
                for: trimmed,
                conversationHistory: messages,
                onPartial: { partial in
                    assistantMessage.content = partial
                }
            )
            assistantMessage.content = response
            scrollToBottom.toggle()
        }
    }

    private func startNewConversation() {
        currentConversationID = UUID()
        assistantService.startNewConversation()
    }
}
