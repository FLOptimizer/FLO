//  View+Modifiers.swift
//  FLO - Finance Ledger Optimizer
//
//  Needs Review
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//

import SwiftUI

extension View {
    // These names are unique — no conflict with your existing .card()
    func appCard() -> some View {
        self
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    func sectionHeader() -> some View {
        self
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 8)
    }
    
    func largeButton() -> some View {
        self
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
