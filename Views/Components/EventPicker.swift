//  EventPicker.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Spending event selection
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Optional event assignment for transactions. Renders nothing when the user
//  has no events, so the feature adds zero clutter until it's used. In "add"
//  flows, an event whose date range covers today is preselected automatically
//  (changeable per transaction) — create "Baseball trip, Jul 4–12" once and
//  every receipt scanned during the trip files itself.
//

import SwiftUI
import SwiftData

/// Form section wrapper — for Form-based flows (Add/Edit Transaction)
struct EventPickerSection: View {
    @Binding var selection: SpendingEvent?
    /// Preselect an event covering today (use in add flows, not edit)
    var autoSelectActive: Bool = false

    @Query(sort: \SpendingEvent.startDate, order: .reverse)
    private var events: [SpendingEvent]

    var body: some View {
        if !events.isEmpty {
            Section {
                EventMenuPicker(selection: $selection, autoSelectActive: autoSelectActive)
            } header: {
                Text("Event")
            } footer: {
                if let event = selection {
                    Text("Counted toward \(event.name) (\(event.dateRangeDisplay))")
                }
            }
        }
    }
}

/// Bare picker — for non-Form layouts (receipt scanner card)
struct EventMenuPicker: View {
    @Binding var selection: SpendingEvent?
    var autoSelectActive: Bool = false

    @Query(sort: \SpendingEvent.startDate, order: .reverse)
    private var events: [SpendingEvent]

    var body: some View {
        if !events.isEmpty {
            Picker("Event", selection: $selection) {
                Label("None", systemImage: "circle.slash")
                    .tag(nil as SpendingEvent?)
                ForEach(events) { event in
                    Label(event.name, systemImage: event.icon)
                        .tag(Optional(event))
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selection) { _, _ in
                HapticService.play(.light)
            }
            .onAppear {
                if autoSelectActive, selection == nil,
                   let active = events.first(where: { $0.isActive }) {
                    selection = active
                }
            }
            .accessibilityLabel("Event: \(selection?.name ?? "None")")
            .accessibilityHint("Optionally assign this transaction to a trip or event")
        }
    }
}
