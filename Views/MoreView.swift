// MoreView.swift
// FLO - Finance Ledger Optimizer
//
// Version 3.5.1 - Added stagger animations to Financial Tools for uniformity
// Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
// CHANGES FROM v3.5:
// ✅ Added stagger animations to Financial Tools section for uniformity
//
// CHANGES FROM v3.4:
// ✅ Added back Financial Tools section from v3.3
//
// CHANGES FROM v3.3:
// ✅ Haptic feedback on menu row taps
// ✅ Section entrance stagger animations
// ✅ Menu row icon scale animation
// ✅ Version info fade animation
//
// CONTENTS:
// - MoreView (main menu)
// - MenuRow (reusable component with haptics)
// - FeatureBullet (reusable component)
// - Bundle extension for version info
//
// PREVIOUS (v3.3):
// - Added Accounts section

import SwiftUI
import SwiftData

struct MoreView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var clients: [Client]
    @Query private var trips: [MileageTrip]
    @Query(filter: #Predicate<Account> { $0.isActive }) private var accounts: [Account]
    @Query private var transactions: [Transaction]
    @Query private var recurringTransactions: [RecurringTransaction]
    
    @State private var viewAppeared = false
    
    // Haptic Generators
        
    // Calculate this month's mileage for subtitle
    private var thisMonthMiles: Double {
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)
        
        return trips
            .filter { $0.isInMonth(month, year: year) && $0.isBusinessTrip }
            .reduce(0) { $0 + $1.distanceMiles }
    }
    // Calculate this month's totals for Reports subtitle
    private var thisMonthSummary: String {
        let calendar = Calendar.current
        let now = Date()
       
        let monthTransactions = transactions.filter { transaction in
            calendar.isDate(transaction.date, equalTo: now, toGranularity: .month)
        }
       
        let income = monthTransactions.filter(\.isIncome).reduce(0) { $0 + $1.amount }
        let expenses = monthTransactions.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
       
        if income == 0 && expenses == 0 {
            return "View charts, trends & export PDFs"
        }
       
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
       
        let incomeStr = formatter.string(from: NSNumber(value: income)) ?? "$0"
        let expenseStr = formatter.string(from: NSNumber(value: expenses)) ?? "$0"
       
        return "\(incomeStr) in · \(expenseStr) out this month"
    }
    // Active recurring count
    private var activeRecurringCount: Int {
        recurringTransactions.filter { $0.isActive }.count
    }
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Financial Tools Section (NEW)
                Section {
                    NavigationLink(destination: ReportsView()) {
                        MenuRow(
                            icon: "chart.pie.fill",
                            iconColor: Color.brandPrimary,
                            title: "Reports & Analytics",
                            subtitle: thisMonthSummary,
                            accessibilityLabel: "Reports and Analytics. View charts, trends, and export reports"
                        )
                    }
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(x: viewAppeared ? 0 : 20)
                    .animation(FLOAnimation.standard.delay(0.0), value: viewAppeared)
                   
                    NavigationLink(destination: RecurringListView()) {
                        MenuRow(
                            icon: "arrow.triangle.2.circlepath",
                            iconColor: .purple,
                            title: "Recurring Transactions",
                            subtitle: activeRecurringCount > 0
                                ? "\(activeRecurringCount) active \(activeRecurringCount == 1 ? "transaction" : "transactions")"
                                : "Set up automatic entries",
                            accessibilityLabel: "Recurring Transactions. \(activeRecurringCount) active recurring transactions"
                        )
                    }
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(x: viewAppeared ? 0 : 20)
                    .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)
                } header: {
                    Text("Financial Tools")
                } footer: {
                    Text("Track your financial health and automate regular transactions")
                }
                // MARK: - Business Tools Section
                Section {
                    NavigationLink(destination: ClientListView()) {
                        MenuRow(
                            icon: "person.2.fill",
                            iconColor: .blue,
                            title: "Clients",
                            subtitle: "\(clients.count) \(clients.count == 1 ? "client" : "clients")",
                            accessibilityLabel: "\(clients.count) total clients"
                        )
                    }
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(x: viewAppeared ? 0 : 20)
                    .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
                    
                    NavigationLink(destination: MileageTrackingMainView()) {
                        MenuRow(
                            icon: "car.fill",
                            iconColor: .green,
                            title: "Mileage Tracking",
                            subtitle: thisMonthMiles > 0
                                ? String(format: "%.0f miles this month", thisMonthMiles)
                                : "Track business miles for deductions",
                            accessibilityLabel: "Mileage Tracking. Track business miles for tax deductions"
                        )
                    }
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(x: viewAppeared ? 0 : 20)
                    .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)
                    
                    NavigationLink(destination: AccountsView()) {
                        MenuRow(
                            icon: "building.columns.fill",
                            iconColor: Color.brandPrimary,
                            title: "Accounts",
                            subtitle: accounts.isEmpty
                                ? "Set up bank accounts & payment methods"
                                : "\(accounts.count) \(accounts.count == 1 ? "account" : "accounts")",
                            accessibilityLabel: "Accounts. Manage bank accounts and payment methods"
                        )
                    }
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(x: viewAppeared ? 0 : 20)
                    .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)
                } header: {
                    Text("Business Tools")
                } footer: {
                    Text("Track clients, mileage, and accounts to maximize your tax deductions")
                }
                
                // MARK: - App Section
                Section {
                    NavigationLink(destination: SettingsView()) {
                        MenuRow(
                            icon: "gearshape.fill",
                            iconColor: .gray,
                            title: "Settings",
                            subtitle: "App preferences and security",
                            accessibilityLabel: "Settings. App preferences and security"
                        )
                    }
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(x: viewAppeared ? 0 : 20)
                    .animation(FLOAnimation.standard.delay(0.25), value: viewAppeared)
                } header: {
                    Text("App")
                }
                
                // MARK: - About Section
                Section {
                    HStack {
                        Text("Version")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(Bundle.main.appVersionLong)
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("App version \(Bundle.main.appVersionLong)")
                    .opacity(viewAppeared ? 1 : 0)
                    .animation(FLOAnimation.standard.delay(0.3), value: viewAppeared)
                    
                    HStack {
                        Text("Mileage Service")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("v\(MileageTrackingService.version)")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                    .opacity(viewAppeared ? 1 : 0)
                    .animation(FLOAnimation.standard.delay(0.35), value: viewAppeared)
                } header: {
                    Text("About")
                } footer: {
                    Text("© 2025 Finch & Poppy Co LLC")
                        .opacity(viewAppeared ? 1 : 0)
                        .animation(FLOAnimation.standard.delay(0.4), value: viewAppeared)
                }
            }
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                withAnimation(FLOAnimation.standard) {
                    viewAppeared = true
                }
                print("📱 MoreView appeared")
            }
            .onDisappear {
                print("📱 MoreView disappeared")
            }
        }
    }
}

// MARK: - Menu Row Component

struct MenuRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let accessibilityLabel: String
    
    @State private var iconAppeared = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 32)
                .symbolRenderingMode(.hierarchical)
                .scaleEffect(iconAppeared ? 1 : 0.5)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: iconAppeared)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .onAppear {
            withAnimation {
                iconAppeared = true
            }
        }
    }
}

// MARK: - Feature Bullet Component

struct FeatureBullet: View {
    let text: String
    @State private var checkmarkAppeared = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .scaleEffect(checkmarkAppeared ? 1 : 0.5)
                .opacity(checkmarkAppeared ? 1 : 0)
            Text(text)
                .font(.subheadline)
        }
        .accessibilityElement(children: .combine)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.1)) {
                checkmarkAppeared = true
            }
        }
    }
}

// MARK: - Bundle Extension

extension Bundle {
    var appVersionLong: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    var appVersionShort: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

// MARK: - Preview

#Preview("More Menu") {
    MoreView()
        .modelContainer(for: [Client.self, MileageTrip.self, Account.self, Transaction.self, RecurringTransaction.self], inMemory: true)
}
