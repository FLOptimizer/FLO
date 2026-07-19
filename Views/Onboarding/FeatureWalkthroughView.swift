//  FeatureWalkthroughView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — Interactive feature discovery walkthrough
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//

import SwiftUI

struct FeatureWalkthroughView: View {
    @AppStorage("hasCompletedWalkthrough") private var hasCompletedWalkthrough = false
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0

    private let steps: [WalkthroughStep] = [
        WalkthroughStep(
            title: "Dashboard",
            description: "Your financial command center. See spending trends, budgets, and quick actions at a glance.",
            icon: "chart.bar.fill",
            color: .blue
        ),
        WalkthroughStep(
            title: "Transactions",
            description: "Track every dollar. Add manually, scan receipts, or import from your bank.",
            icon: "creditcard.fill",
            color: .green
        ),
        WalkthroughStep(
            title: "Budgets",
            description: "Set monthly budgets by category. FLO tracks spending and alerts you at 80%.",
            icon: "chart.pie.fill",
            color: .orange
        ),
        WalkthroughStep(
            title: "Receipts",
            description: "Scan receipts with your camera. FLO reads the merchant, amount, and date automatically.",
            icon: "doc.text.viewfinder",
            color: .purple
        ),
        WalkthroughStep(
            title: "Invoices",
            description: "Create professional invoices and track payments. PDF generation included.",
            icon: "doc.text.fill",
            color: .teal
        ),
        WalkthroughStep(
            title: "Tax Tools",
            description: "Year-round tax prep. Deduction tracking, P&L reports, and CPA export.",
            icon: "building.columns.fill",
            color: .red
        ),
        WalkthroughStep(
            title: "Mileage",
            description: "Track business miles with GPS or manual entry. IRS-compliant reporting.",
            icon: "car.fill",
            color: .cyan
        ),
        WalkthroughStep(
            title: "You're All Set!",
            description: "Explore FLO at your own pace. You can replay this walkthrough anytime from Settings.",
            icon: "checkmark.seal.fill",
            color: .brandPrimary
        ),
    ]

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Card
                VStack(spacing: 24) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(steps[currentStep].color.opacity(0.15))
                            .frame(width: 80, height: 80)
                        Image(systemName: steps[currentStep].icon)
                            .font(.system(size: 36))
                            .foregroundStyle(steps[currentStep].color)
                    }
                    .transition(.scale.combined(with: .opacity))

                    // Title & Description
                    VStack(spacing: 8) {
                        Text(steps[currentStep].title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Text(steps[currentStep].description)
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 8)
                }
                .padding(32)
                .frame(maxWidth: 360)
                .background(.ultraThinMaterial.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .id(currentStep) // Forces view recreation for transition
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                Spacer()

                // Page dots
                HStack(spacing: 6) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentStep ? Color.white : Color.white.opacity(0.3))
                            .frame(width: index == currentStep ? 8 : 6, height: index == currentStep ? 8 : 6)
                            .animation(.easeInOut(duration: 0.2), value: currentStep)
                    }
                }
                .padding(.bottom, 24)

                // Navigation buttons
                HStack {
                    if currentStep > 0 {
                        Button("Back") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep -= 1
                            }
                        }
                        .foregroundStyle(.white.opacity(0.7))
                    }

                    Spacer()

                    if currentStep < steps.count - 1 {
                        Button("Skip") {
                            completeWalkthrough()
                        }
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.trailing, 16)

                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep += 1
                            }
                        } label: {
                            Text("Next")
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(steps[currentStep].color)
                                .clipShape(Capsule())
                        }
                    } else {
                        Button {
                            completeWalkthrough()
                        } label: {
                            Text("Get Started")
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(Color.brandPrimary)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Feature walkthrough, step \(currentStep + 1) of \(steps.count)")
    }

    private func completeWalkthrough() {
        hasCompletedWalkthrough = true
        HapticService.shared.success()
        dismiss()
    }
}

// MARK: - Walkthrough Step Model

struct WalkthroughStep {
    let title: String
    let description: String
    let icon: String
    let color: Color
}

#Preview {
    FeatureWalkthroughView()
}
