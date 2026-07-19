//  ClientManagementViews.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 4.3 - Size-class-aware edit routing (Catalyst/iPad Zone 3) · Dark Mode Optimization
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v4.2 - Dark Mode Optimization:
//  ✅ FIXED: L401 Color.gray → Color.gray.opacity(0.3) for status dot fill (adapts to dark mode)
//
//  CHANGES v4.1 - Dynamic Type Verification:
//  ✅ FIXED: "Client Management" title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Locked view description text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: AnimatedFeatureRow text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Upgrade to Pro" button text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Pricing text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Empty state "No Clients Yet" title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Empty state description text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: AnimatedClientRow name missing lineLimit + minimumScaleFactor
//  ✅ FIXED: AnimatedClientRow email missing lineLimit + minimumScaleFactor
//  ✅ FIXED: AnimatedClientRow initials text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: ClientDetailView LabeledContent labels and values missing protections
//  ✅ FIXED: "No invoices yet" text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Payment terms picker labels missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Status picker labels missing lineLimit + minimumScaleFactor
//  ✅ FIXED: FeatureCheckmarkRowClient text missing lineLimit + minimumScaleFactor
//
//  ENHANCEMENTS v3.0:
//  - Animated locked view with icon bounce
//  - Staggered feature row animations
//  - Upgrade button press effect
//  - Client row hover states
//  - Delete confirmation haptics
//  - Form field focus animations
//  - Save button feedback
//

import SwiftUI
import SwiftData
import FLODesignSystem

// MARK: - Client List View (With Gating Wrapper)

struct ClientListView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showingPaywall = false
    
    var body: some View {
        Group {
            if subscriptionManager.currentTier.hasClientManagement {
                ClientListContentView()
            } else {
                lockedClientView
            }
        }
        .sheet(isPresented: $showingPaywall) {
            SubscriptionView()
        }
    }
    
    // MARK: - Locked View
    
    private var lockedClientView: some View {
        AnimatedLockedClientView(showingPaywall: $showingPaywall)
    }
}

// MARK: - Animated Locked Client View

struct AnimatedLockedClientView: View {
    @Binding var showingPaywall: Bool
    
    // Animation States
    @State private var iconVisible = false
    @State private var textVisible = false
    @State private var featuresVisible = false
    @State private var buttonVisible = false
    @State private var iconBounce = false
    @State private var upgradeButtonScale: CGFloat = 1.0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer().frame(height: 40)
                
                Image(systemName: "person.2.fill")
                    .font(.largeTitle)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.brandPrimary.opacity(0.3), Color.brandPrimary.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(iconVisible ? 1.0 : 0.5)
                    .opacity(iconVisible ? 1 : 0.001)
                    .offset(y: iconBounce ? -5 : 0)
                    .accessibilityHidden(true)
                
                VStack(spacing: 12) {
                    Text("Client Management")
                        .font(.title2.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .accessibilityAddTraits(.isHeader)
                    Text("Upgrade to Pro to manage unlimited clients, track payment history, and build lasting relationships.")
                        .font(.body)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .opacity(textVisible ? 1 : 0.001)
                .offset(y: textVisible ? 0 : 10)
                
                VStack(alignment: .leading, spacing: 16) {
                    AnimatedFeatureRow(icon: "person.crop.circle.fill.badge.plus", text: "Unlimited client profiles", delay: 0, isVisible: featuresVisible)
                    AnimatedFeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Payment history tracking", delay: 0.05, isVisible: featuresVisible)
                    AnimatedFeatureRow(icon: "envelope.fill", text: "Contact information management", delay: 0.1, isVisible: featuresVisible)
                    AnimatedFeatureRow(icon: "doc.text.fill", text: "Client-specific invoicing", delay: 0.15, isVisible: featuresVisible)
                    AnimatedFeatureRow(icon: "clock.fill", text: "Payment terms & preferences", delay: 0.2, isVisible: featuresVisible)
                }
                .padding(.horizontal, 32)
                
                Button {

                    HapticService.play(.medium)
                    
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        upgradeButtonScale = 0.95
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                            upgradeButtonScale = 1.0
                        }
                    }
                    
                    showingPaywall = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .accessibilityHidden(true)
                        Text("Upgrade to Pro")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.brandPrimary, Color.brandPrimary.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .scaleEffect(upgradeButtonScale)
                }
                .padding(.horizontal, 32)
                .opacity(buttonVisible ? 1 : 0.001)
                .offset(y: buttonVisible ? 0 : 20)
                
                VStack(spacing: 4) {
                    Text("$19.99/month")
                        .font(.subheadline.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("Everything in Premium + Pro features")
                        .font(.caption)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(.secondary)
                }
                .opacity(buttonVisible ? 1 : 0.001)
                
                Spacer()
            }
        }
        .navigationTitle("Clients")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            DispatchQueue.main.async {
                animateEntrance()
            }
            AccessibilityAnnouncement.screenChanged("Client management, upgrade required")
        }
    }
    
    private func animateEntrance() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            iconVisible = true
        }
        
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(0.5)) {
            iconBounce = true
        }
        
        withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
            textVisible = true
        }
        
        withAnimation(.easeOut(duration: 0.3).delay(0.3)) {
            featuresVisible = true
        }
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.6)) {
            buttonVisible = true
        }
    }
}

// MARK: - Animated Feature Row

struct AnimatedFeatureRow: View {
    let icon: String
    let text: String
    let delay: Double
    let isVisible: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.brandPrimary)
                .frame(width: 32)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
        }
        .opacity(isVisible ? 1 : 0.001)
        .offset(x: isVisible ? 0 : -20)
        .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(delay), value: isVisible)
    }
}

// MARK: - Client List Content View

struct ClientListContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Client.name) private var clients: [Client]
    
    @State private var searchText = ""
    @State private var showingCreateClient = false
    @State private var clientToDelete: Client?
    @State private var showingDeleteAlert = false
    
    // Animation States
    @State private var listVisible = false
    
    var filteredClients: [Client] {
        if searchText.isEmpty {
            return clients
        }
        return clients.filter { client in
            client.name.localizedCaseInsensitiveContains(searchText) ||
            client.email?.localizedCaseInsensitiveContains(searchText) ?? false
        }
    }
    
    var body: some View {
        Group {
            if clients.isEmpty {
                VStack(spacing: 16) {
                    ClientsIllustration()
                    
                    Text("No Clients Yet")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    Text("Add clients to track invoices and manage business relationships")
                        .font(.subheadline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        HapticService.play(.medium)
                        showingCreateClient = true
                    } label: {
                        Text("Add Your First Client")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.brandPrimary)
                    .accessibilityLabel("Add your first client")
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
            } else {
                List {
                    ForEach(Array(filteredClients.enumerated()), id: \.element.id) { index, client in
                        NavigationLink(destination: ClientDetailView(client: client)) {
                            AnimatedClientRow(client: client, delay: Double(index) * 0.03, isVisible: listVisible)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {

                                HapticService.play(.medium)
                                clientToDelete = client
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .searchable(text: $searchText, prompt: "Search clients")
                .onAppear {
                    DispatchQueue.main.async {
                        withAnimation(.easeOut(duration: 0.3)) {
                            listVisible = true
                        }
                    }
                }
            }
        }
        .navigationTitle("Clients")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {

                    HapticService.play(.medium)
                    showingCreateClient = true
                } label: {
                    Image(systemName: "plus")
                        .symbolVariant(.circle.fill)
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                }
                .accessibilityLabel("Add client")
            }
        }
        .sheet(isPresented: $showingCreateClient) {
            CreateClientView()
        }
        .confirmationDialog(
            "Delete Client",
            isPresented: $showingDeleteAlert,
            titleVisibility: .visible,
            presenting: clientToDelete
        ) { client in
            Button("Delete \(client.name)", role: .destructive) {
                HapticService.shared.success()
                
                withAnimation {
                    modelContext.delete(client)
                    try? modelContext.save()
                }
            }
            Button("Cancel", role: .cancel) {

                HapticService.play(.medium)
            }
        } message: { client in
            Text("Are you sure you want to delete \(client.name)? This action cannot be undone.")
        }
    }
}

// MARK: - Animated Client Row

struct AnimatedClientRow: View {
    let client: Client
    let delay: Double
    let isVisible: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.brandPrimary.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Text(client.initials)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(Color.brandPrimary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(client.name)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                if let email = client.email {
                    Text(email)
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Status indicator
            Circle()
                .fill(client.status == .active ? Color.incomeGreen : Color.floCardBorder)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 4)
        .opacity(isVisible ? 1 : 0.001)
        .offset(x: isVisible ? 0 : -10)
        .animation(.easeOut(duration: 0.3).delay(delay), value: isVisible)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(clientRowAccessibilityLabel)
    }
    
    private var clientRowAccessibilityLabel: String {
        var parts = [client.name]
        if let email = client.email { parts.append(email) }
        parts.append(client.status == .active ? "Active" : "Inactive")
        return parts.joined(separator: ", ")
    }
}

// MARK: - Client Detail View (Original - Unchanged)

struct ClientDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var client: Client
    #if !os(macOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    @State private var showingEditSheet = false

    /// Route edit to the Zone 3 pane on a wide layout (native macOS, iPad
    /// landscape, wide Mac Catalyst window); use a sheet on compact. Replaces the
    /// old hard `#if os(macOS)` switch, which was dead on Catalyst.
    private var routesToDetailPane: Bool {
        #if os(macOS)
        return true
        #else
        return horizontalSizeClass == .regular
        #endif
    }

    var body: some View {
        List {
            Section("Contact Information") {
                LabeledContent {
                    Text(client.name)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } label: {
                    Text("Company")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                
                if let contact = client.contactName {
                    LabeledContent {
                        Text(contact)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    } label: {
                        Text("Contact")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                if let email = client.email {
                    LabeledContent {
                        Text(email)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    } label: {
                        Text("Email")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                if let phone = client.phone {
                    LabeledContent {
                        Text(phone)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    } label: {
                        Text("Phone")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
            
            Section("Business Details") {
                LabeledContent {
                    Text("Net \(client.defaultPaymentTerms)")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } label: {
                    Text("Payment Terms")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                
                LabeledContent {
                    Text(client.status == .active ? "Active" : "Inactive")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } label: {
                    Text("Status")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            
            if let notes = client.notes {
                Section("Notes") {
                    Text(notes)
                        .font(.body)
                }
            }
            
            Section("Invoices") {
                if let invoices = client.invoices, !invoices.isEmpty {
                    ForEach(invoices.sorted(by: { $0.dueDate > $1.dueDate })) { invoice in
                        NavigationLink(value: invoice) {
                            InvoiceRow(invoice: invoice)
                        }
                    }
                } else {
                    Text("No invoices yet")
                        .font(.body)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle(client.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Invoice.self) { invoice in
            InvoiceDetailView(invoice: invoice)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if routesToDetailPane {
                        withAnimation(FLOAnimation.quick) {
                            NavigationService.shared.selectedDetail = .editClient(id: client.id)
                        }
                    } else {
                        showingEditSheet = true
                    }
                } label: {
                    Text("Edit")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditClientView(client: client)
        }
        .onAppear {
            AccessibilityAnnouncement.screenChanged("Client details, \(client.name)")
        }
    }
}

// MARK: - Create Client View

struct CreateClientView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var name = ""
    @State private var contactName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var defaultPaymentTerms = 30
    @State private var notes = ""
    
    // Animation States
    @State private var saveButtonScale: CGFloat = 1.0
    
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case name, contactName, email, phone, notes
    }
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Company Name *", text: $name)
                        .textContentType(.organizationName)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .name)
                        .onSubmit { focusedField = .contactName }
                    
                    TextField("Contact Name (optional)", text: $contactName)
                        .textContentType(.name)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .contactName)
                        .onSubmit { focusedField = .email }
                    
                    TextField("Email (optional)", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .email)
                        .onSubmit { focusedField = .phone }
                    
                    TextField("Phone (optional)", text: $phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                        .focused($focusedField, equals: .phone)
                        .onSubmit { focusedField = .notes }
                }
                
                Section("Payment Terms") {
                    Picker("Default Payment Terms", selection: $defaultPaymentTerms) {
                        Text("Due on Receipt")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .tag(0)
                        Text("Net 15")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .tag(15)
                        Text("Net 30")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .tag(30)
                        Text("Net 60")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .tag(60)
                    }
                    .onChange(of: defaultPaymentTerms) { _, _ in
                        HapticService.shared.selection()
                    }
                }
                
                Section("Notes") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .focused($focusedField, equals: .notes)
                }
            }
            .navigationTitle("New Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
   
                        HapticService.play(.medium)
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveClient()
                    }
                    .disabled(!isValid)
                    .scaleEffect(saveButtonScale)
                }
            }
            .onAppear {
                focusedField = .name
                AccessibilityAnnouncement.screenChanged("New client")
            }
        }
    }
    
    private func saveClient() {

        HapticService.play(.medium)
        
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            saveButtonScale = 0.9
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                saveButtonScale = 1.0
            }
        }
        
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let client = Client(
            name: trimmedName,
            contactName: contactName.isEmpty ? nil : contactName,
            email: email.isEmpty ? nil : email,
            phone: phone.isEmpty ? nil : phone,
            defaultPaymentTerms: defaultPaymentTerms,
            notes: notes.isEmpty ? nil : notes,
            status: .active
        )
        
        modelContext.insert(client)
        try? modelContext.save()
        
        // Success haptic
        HapticService.shared.success()
        
        dismiss()
    }
}

// MARK: - Edit Client View

struct EditClientView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var client: Client

    // Zone 3 adaptive presentation — when false, omits NavigationStack wrapper.
    var embedInNavigationStack: Bool = true
    /// Zone 3 dismiss callback — called instead of SwiftUI `dismiss()` when set.
    var onDismiss: (() -> Void)? = nil

    @State private var saveButtonScale: CGFloat = 1.0

    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case name, contactName, email, phone, notes
    }
    
    private var isValid: Bool {
        !client.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        if embedInNavigationStack {
            NavigationStack { formContent }
        } else {
            formContent
        }
    }

    @ViewBuilder
    private var formContent: some View {
            Form {
                Section("Basic Information") {
                    TextField("Company Name", text: $client.name)
                        .textContentType(.organizationName)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .name)
                    
                    TextField("Contact Name (optional)", text: Binding(
                        get: { client.contactName ?? "" },
                        set: { client.contactName = $0.isEmpty ? nil : $0 }
                    ))
                    .textContentType(.name)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .contactName)
                    
                    TextField("Email (optional)", text: Binding(
                        get: { client.email ?? "" },
                        set: { client.email = $0.isEmpty ? nil : $0 }
                    ))
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .email)
                    
                    TextField("Phone (optional)", text: Binding(
                        get: { client.phone ?? "" },
                        set: { client.phone = $0.isEmpty ? nil : $0 }
                    ))
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
                    .focused($focusedField, equals: .phone)
                }
                
                Section("Payment Terms") {
                    Picker("Default Payment Terms", selection: $client.defaultPaymentTerms) {
                        Text("Due on Receipt")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .tag(0)
                        Text("Net 15")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .tag(15)
                        Text("Net 30")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .tag(30)
                        Text("Net 60")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .tag(60)
                    }
                    .onChange(of: client.defaultPaymentTerms) { _, _ in
                        HapticService.shared.selection()
                    }
                }
                
                Section("Status") {
                    Picker("Client Status", selection: $client.status) {
                        Text("Active")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .tag(ClientStatus.active)
                        Text("Inactive")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .tag(ClientStatus.inactive)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: client.status) { _, _ in
                        HapticService.shared.selection()
                    }
                }
                
                Section("Notes") {
                    TextField("Notes (optional)", text: Binding(
                        get: { client.notes ?? "" },
                        set: { client.notes = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .lineLimit(3...6)
                    .focused($focusedField, equals: .notes)
                }
            }
            .navigationTitle("Edit Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
  
                        HapticService.play(.medium)
                        
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                            saveButtonScale = 0.9
                        }
                        
                        try? modelContext.save()

                        HapticService.shared.success()

                        performDismiss()
                    }
                    .disabled(!isValid)
                    .scaleEffect(saveButtonScale)
                }
            }
            .onAppear {
                AccessibilityAnnouncement.screenChanged("Edit client")
            }
    }

    private func performDismiss() {
        if let onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }
}

// MARK: - Gating UI Component

struct FeatureCheckmarkRowClient: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.brandPrimary)
                .frame(width: 32)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
        }
    }
}

// Note: Client.initials and Client.paymentTermsDisplay extensions are defined in Client.swift

// MARK: - Previews

#Preview("Empty List") {
    NavigationStack {
        ClientListView()
            .modelContainer(for: [Client.self], inMemory: true)
    }
}

#Preview("Locked View") {
    NavigationStack {
        AnimatedLockedClientView(showingPaywall: .constant(false))
    }
}
