//  BusinessProfileDiagnosticView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.0 - Enhanced with Haptics & Micro-Animations
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  Diagnostic Tool for BusinessProfile persistence issues
//
//  ENHANCEMENTS v2.0:
//  - Animated test result entries with staggered delays
//  - Success/failure icons with bounce effect
//  - Run diagnostics button with press animation
//  - Progress indicator during tests
//  - Celebration animation on all tests passed
//  - Haptic feedback for test results
//

import SwiftUI
import SwiftData

struct BusinessProfileDiagnosticView: View {
    @Environment(\.modelContext) private var modelContext
    
    @State private var diagnosticResults: [DiagnosticResult] = []
    @State private var testPassed = false
    @State private var isRunning = false
    
    // Animation States
    @State private var resultsVisible = false
    @State private var runButtonScale: CGFloat = 1.0
    @State private var createButtonScale: CGFloat = 1.0
    @State private var celebrationScale: CGFloat = 1.0
    
    var body: some View {
        List {
            Section("Diagnostic Results") {
                if diagnosticResults.isEmpty && !isRunning {
                    HStack {
                        Image(systemName: "stethoscope")
                            .foregroundStyle(.secondary)
                        Text("Tap 'Run Diagnostics' below")
                            .foregroundStyle(.secondary)
                    }
                } else if isRunning {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Running diagnostics...")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(Array(diagnosticResults.enumerated()), id: \.offset) { index, result in
                        AnimatedDiagnosticRow(
                            result: result,
                            delay: Double(index) * 0.05,
                            isVisible: resultsVisible
                        )
                    }
                }
            }
            
            Section {
                Button {
                    runDiagnosticsAnimated()
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Run Diagnostics")
                    }
                    .frame(maxWidth: .infinity)
                    .scaleEffect(runButtonScale)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRunning)
                
                if testPassed {
                    Button {
                        createTestProfileAnimated()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Create Test Profile")
                        }
                        .frame(maxWidth: .infinity)
                        .scaleEffect(createButtonScale)
                    }
                    .buttonStyle(.bordered)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            
            if testPassed {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.green)
                                .scaleEffect(celebrationScale)
                            
                            Text("All Tests Passed!")
                                .font(.headline)
                                .foregroundStyle(.green)
                            
                            Text("BusinessProfile persistence is working correctly")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        Spacer()
                    }
                    .padding(.vertical)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .navigationTitle("Diagnostics")
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: testPassed)
    }
    
    // MARK: - Animated Actions
    
    private func runDiagnosticsAnimated() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            runButtonScale = 0.95
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                runButtonScale = 1.0
            }
        }
        
        // Reset state
        diagnosticResults = []
        testPassed = false
        resultsVisible = false
        isRunning = true
        
        // Run diagnostics with slight delay for visual effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            runDiagnostics()
        }
    }
    
    private func createTestProfileAnimated() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            createButtonScale = 0.95
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                createButtonScale = 1.0
            }
        }
        
        createTestProfile()
    }
    
    // MARK: - Diagnostics
    
    private func runDiagnostics() {
        var results: [DiagnosticResult] = []
        
        print("\n🔍 ===== STARTING DIAGNOSTICS =====\n")
        
        // Test 1: Check ModelContainer schema
        results.append(DiagnosticResult(text: "Test 1: ModelContainer Schema", type: .header))
        
        let container = modelContext.container
        let entities = container.schema.entities.map { $0.name }
        
        print("📦 All models in schema:")
        entities.forEach { print("  - \($0)") }
        
        if entities.contains("BusinessProfile") {
            results.append(DiagnosticResult(text: "BusinessProfile IS in schema", type: .success))
            print("✅ BusinessProfile IS in schema")
        } else {
            results.append(DiagnosticResult(text: "BusinessProfile NOT in schema", type: .error))
            results.append(DiagnosticResult(text: "This is the problem! ModelContainer_Shared.swift not updated.", type: .warning))
            print("❌ BusinessProfile NOT in schema - THIS IS THE PROBLEM!")
            
            finishDiagnostics(results: results, passed: false)
            return
        }
        
        // Test 2: Check if we can create a BusinessProfile object
        let _ = BusinessProfile(
            businessName: "Test Company",
            email: "test@test.com"
        )
        results.append(DiagnosticResult(text: "Can create BusinessProfile object", type: .success))
        print("✅ Can create BusinessProfile object")
        
        // Test 3: Check database file location
        results.append(DiagnosticResult(text: "Test 3: Database Location", type: .header))
        if let storeURL = container.configurations.first?.url {
            results.append(DiagnosticResult(text: "Database: \(storeURL.lastPathComponent)", type: .info))
            print("💾 Database URL: \(storeURL)")
            
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: storeURL.path) {
                results.append(DiagnosticResult(text: "Database file exists", type: .success))
                print("✅ Database file exists")
            } else {
                results.append(DiagnosticResult(text: "Database file doesn't exist yet (will be created on first save)", type: .warning))
                print("⚠️ Database file doesn't exist yet")
            }
        } else {
            results.append(DiagnosticResult(text: "Cannot determine database location", type: .error))
            print("❌ Cannot determine database location")
        }
        
        // Test 4: Try to insert and save
        results.append(DiagnosticResult(text: "Test 4: Insert & Save Test", type: .header))
        let testProfile = BusinessProfile(
            businessName: "Diagnostic Test \(Date().timeIntervalSince1970)",
            email: "diagnostic@test.com"
        )
        
        print("💾 Attempting to insert test profile...")
        modelContext.insert(testProfile)
        
        do {
            print("💾 Attempting to save...")
            try modelContext.save()
            results.append(DiagnosticResult(text: "Save succeeded!", type: .success))
            print("✅ Save succeeded!")
            
            // Test 5: Try to fetch it back
            results.append(DiagnosticResult(text: "Test 5: Fetch Verification", type: .header))
            let descriptor = FetchDescriptor<BusinessProfile>()
            let profiles = try modelContext.fetch(descriptor)
            
            print("🔍 Found \(profiles.count) profiles")
            results.append(DiagnosticResult(text: "Found \(profiles.count) profile(s)", type: .success))
            
            if let found = profiles.first {
                results.append(DiagnosticResult(text: "Profile name: \(found.businessName)", type: .success))
                results.append(DiagnosticResult(text: "Profile email: \(found.email)", type: .success))
                print("✅ Fetched back profile: \(found.businessName)")
                
                results.append(DiagnosticResult(text: "ALL TESTS PASSED!", type: .celebration))
                results.append(DiagnosticResult(text: "BusinessProfile persistence is working!", type: .success))
                print("\n🎉 ALL TESTS PASSED - BusinessProfile persistence working!\n")
                
                finishDiagnostics(results: results, passed: true)
            } else {
                results.append(DiagnosticResult(text: "No profiles found after save", type: .error))
                print("❌ No profiles found after save")
                finishDiagnostics(results: results, passed: false)
            }
            
            // Clean up test data
            for profile in profiles {
                if profile.businessName.contains("Diagnostic Test") {
                    modelContext.delete(profile)
                }
            }
            try modelContext.save()
            
        } catch {
            results.append(DiagnosticResult(text: "Save failed: \(error.localizedDescription)", type: .error))
            results.append(DiagnosticResult(text: "Error type: \(type(of: error))", type: .warning))
            print("❌ Save failed: \(error)")
            finishDiagnostics(results: results, passed: false)
        }
        
        print("\n🔍 ===== DIAGNOSTICS COMPLETE =====\n")
    }
    
    private func finishDiagnostics(results: [DiagnosticResult], passed: Bool) {
        isRunning = false
        diagnosticResults = results
        
        withAnimation(.easeOut(duration: 0.3)) {
            resultsVisible = true
        }
        
        if passed {
            // Success haptic
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.3)) {
                testPassed = true
            }
            
            // Celebration animation
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.5)) {
                celebrationScale = 1.1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    celebrationScale = 1.0
                }
            }
            
            // Extra celebration haptic
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let celebrationGenerator = UIImpactFeedbackGenerator(style: .heavy)
                celebrationGenerator.impactOccurred()
            }
        } else {
            // Failure haptic
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }
    
    private func createTestProfile() {
        diagnosticResults.append(DiagnosticResult(text: "Creating permanent test profile...", type: .info))
        
        let profile = BusinessProfile(
            businessName: "Urban Cowboy",
            email: "ttcn@example.com",
            phone: "9519727164",
            website: "www.yourbusiness.com",
            taxId: "12-3456789"
        )
        
        modelContext.insert(profile)
        
        do {
            try modelContext.save()
            diagnosticResults.append(DiagnosticResult(text: "Test profile created!", type: .success))
            diagnosticResults.append(DiagnosticResult(text: "Go back to Business Profile to see it", type: .info))
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            print("✅ Test profile created successfully")
        } catch {
            diagnosticResults.append(DiagnosticResult(text: "Failed to create test profile: \(error.localizedDescription)", type: .error))
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            
            print("❌ Failed to create test profile: \(error)")
        }
        
        withAnimation(.easeOut(duration: 0.3)) {
            resultsVisible = true
        }
    }
}

// MARK: - Diagnostic Result Model

struct DiagnosticResult: Identifiable {
    let id = UUID()
    let text: String
    let type: ResultType
    
    enum ResultType {
        case header
        case success
        case error
        case warning
        case info
        case celebration
        
        var icon: String {
            switch self {
            case .header: return "arrow.right.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .error: return "xmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            case .celebration: return "party.popper.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .header: return .blue
            case .success: return .green
            case .error: return .red
            case .warning: return .orange
            case .info: return .secondary
            case .celebration: return .purple
            }
        }
    }
}

// MARK: - Animated Diagnostic Row

struct AnimatedDiagnosticRow: View {
    let result: DiagnosticResult
    let delay: Double
    let isVisible: Bool
    
    @State private var iconBounce = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: result.type.icon)
                .foregroundStyle(result.type.color)
                .scaleEffect(iconBounce ? 1.2 : 1.0)
            
            Text(result.text)
                .font(result.type == .header ? .subheadline.bold() : .subheadline)
                .foregroundStyle(result.type.color)
        }
        .opacity(isVisible ? 1 : 0)
        .offset(x: isVisible ? 0 : -10)
        .animation(.spring(response: 0.3, dampingFraction: 0.7).delay(delay), value: isVisible)
        .onChange(of: isVisible) { _, newValue in
            if newValue && (result.type == .success || result.type == .celebration) {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.2) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                        iconBounce = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                            iconBounce = false
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        BusinessProfileDiagnosticView()
            .modelContainer(for: [BusinessProfile.self])
    }
}
