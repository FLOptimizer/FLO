//  EventsListView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Trip/event expense grouping
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Events give transactions a second, time-bounded dimension of
//  categorization: "the July 4–12 baseball trip cost $840 — $390 dining,
//  $310 gas, $140 fees" — while every transaction keeps its normal category.
//

import SwiftUI
import SwiftData

// MARK: - Events List

struct EventsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SpendingEvent.startDate, order: .reverse)
    private var events: [SpendingEvent]

    @State private var showingAddEvent = false
    @State private var eventToDelete: SpendingEvent?
    @State private var showingDeleteConfirmation = false

    var body: some View {
        List {
            if events.isEmpty {
                emptyState
            } else {
                if events.contains(where: { $0.isActive }) {
                    Section("Happening Now") {
                        ForEach(events.filter { $0.isActive }) { event in
                            eventRow(event)
                        }
                    }
                }
                Section(events.contains(where: { $0.isActive }) ? "All Events" : "Events") {
                    ForEach(events.filter { !$0.isActive }) { event in
                        eventRow(event)
                    }
                }
            }
        }
        .navigationTitle("Events")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticService.play(.medium)
                    showingAddEvent = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                }
                .accessibilityLabel("Add event")
            }
        }
        .sheet(isPresented: $showingAddEvent) {
            EventFormView()
        }
        .alert("Delete Event?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let event = eventToDelete {
                    deleteEvent(event)
                }
            }
        } message: {
            Text("Transactions keep their categories — they just won't be grouped under this event anymore.")
        }
        .onAppear {
            AccessibilityAnnouncement.screenChanged("Events. \(events.count) total.")
        }
    }

    private var emptyState: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "airplane.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color.brandPrimary.opacity(0.6))
                    .accessibilityHidden(true)
                Text("Group spending by trip or occasion")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text("Create an event like \"Baseball trip, Jul 4–12\" and transactions from those days are grouped automatically — so you can see what the trip cost in total, broken down by category.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    HapticService.play(.medium)
                    showingAddEvent = true
                } label: {
                    Text("Create Your First Event")
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.brandPrimary)
                        .cornerRadius(10)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
    }

    private func eventRow(_ event: SpendingEvent) -> some View {
        NavigationLink {
            EventDetailView(event: event)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: event.icon)
                    .foregroundStyle(Color.brandPrimary)
                    .frame(width: 30)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(event.dateRangeDisplay)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(event.totalSpent, format: .currency(code: "USD"))
                        .font(.subheadline.weight(.semibold))
                    Text("\(event.transactionCount) items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                eventToDelete = event
                showingDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityLabel("\(event.name), \(event.dateRangeDisplay), total \(AccessibilityFormatters.spokenCurrency(event.totalSpent)), \(event.transactionCount) transactions")
    }

    private func deleteEvent(_ event: SpendingEvent) {
        HapticService.play(.heavy)
        modelContext.delete(event)
        do {
            try modelContext.save()
            HapticService.play(.success)
        } catch {
            HapticService.play(.error)
            print("Failed to delete event: \(error)")
        }
    }
}

// MARK: - Event Form (Add / Edit)

struct EventFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Pass an existing event to edit; nil creates a new one
    var event: SpendingEvent?

    @State private var name = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var notes = ""
    @State private var icon = "airplane"
    @State private var showingSaveError = false

    private let iconChoices = [
        "airplane", "car.fill", "figure.baseball", "tent.fill",
        "gift.fill", "fork.knife", "graduationcap.fill", "briefcase.fill",
        "heart.fill", "star.fill"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Event Details") {
                    TextField("Name (e.g. Baseball trip)", text: $name)
                        .textInputAutocapitalization(.words)
                        .accessibilityLabel("Event name")

                    DatePicker("Starts", selection: $startDate, displayedComponents: .date)
                    DatePicker("Ends", selection: $endDate, in: startDate..., displayedComponents: .date)
                }

                Section("Icon") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(iconChoices, id: \.self) { choice in
                                Button {
                                    HapticService.play(.light)
                                    icon = choice
                                } label: {
                                    Image(systemName: choice)
                                        .font(.title3)
                                        .foregroundStyle(icon == choice ? .white : Color.brandPrimary)
                                        .frame(width: 44, height: 44)
                                        .background(icon == choice ? Color.brandPrimary : Color.brandPrimary.opacity(0.1))
                                        .clipShape(Circle())
                                }
                                .accessibilityLabel("Icon \(choice)")
                                .accessibilityAddTraits(icon == choice ? [.isSelected] : [])
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Notes (Optional)") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(event == nil ? "New Event" : "Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticService.play(.light)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.semibold)
                }
            }
            .alert("Save Failed", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("The event couldn't be saved. Please try again.")
            }
            .onAppear {
                if let event {
                    name = event.name
                    startDate = event.startDate
                    endDate = event.endDate
                    notes = event.notes
                    icon = event.icon
                }
            }
        }
        .floMacSheetFrame()
    }

    private func save() {
        HapticService.play(.medium)
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        if let event {
            event.name = trimmedName
            event.startDate = startDate
            event.endDate = endDate
            event.notes = notes
            event.icon = icon
        } else {
            let newEvent = SpendingEvent(
                name: trimmedName,
                startDate: startDate,
                endDate: endDate,
                notes: notes,
                icon: icon
            )
            modelContext.insert(newEvent)
        }

        do {
            try modelContext.save()
            HapticService.play(.success)
            AccessibilityAnnouncement.announce("Event saved")
            dismiss()
        } catch {
            HapticService.play(.error)
            showingSaveError = true
        }
    }
}
