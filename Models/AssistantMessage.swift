//  AssistantMessage.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 — My Assistant chat message model.
//  Persists conversation history via SwiftData + CloudKit sync.
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import Foundation
import SwiftData

@Model
final class AssistantMessage {
    var content: String = ""
    var isUser: Bool = true
    var timestamp: Date = Date()
    var conversationID: UUID = UUID()

    init(content: String, isUser: Bool, conversationID: UUID = UUID()) {
        self.content = content
        self.isUser = isUser
        self.timestamp = Date()
        self.conversationID = conversationID
    }
}
