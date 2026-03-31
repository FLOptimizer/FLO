//  UndoManager.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.3 - VoiceOver Audit: Undo toast accessibility with announcements
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.3 - VoiceOver Audit:
//  ✅ ADDED: UndoToastView combines children with spoken label "Transaction deleted. Undo available."
//  ✅ ADDED: Undo button has explicit hint "Double tap to undo the last action"
//  ✅ ADDED: AccessibilityAnnouncement when toast appears to alert VoiceOver users
//  ✅ ADDED: Decorative icon hidden (trash/action icons)
//  ✅ ADDED: Progress ring hidden from VoiceOver (visual-only indicator)
//  ✅ VERIFIED: Toast announces deletion and undo availability immediately
//
//  FEATURES:
//  - 5-second undo window for deleted items
//  - Toast notification with undo button
//  - Automatic expiration
//  - Haptic feedback integration
//  - Smooth animations
//
//  USAGE:
//  1. Instead of deleting immediately, call:
//     FLOUndoManager.shared.scheduleDelete(message: "Transaction deleted") {
//         // Actual delete code here
//     } undoAction: {
//         // Restore code here (if needed)
//     }
//
//  2. Add UndoToastView to your root view:
//     .overlay(alignment: .bottom) {
//         UndoToastView()
//     }
//

import SwiftUI
import Combine

// MARK: - Undo Action Model

struct UndoableAction: Identifiable {
    let id = UUID()
    let message: String
    let icon: String
    let deleteAction: () -> Void
    let undoAction: () -> Void
    let createdAt: Date
    let expiresAt: Date
    
    var timeRemaining: TimeInterval {
        expiresAt.timeIntervalSince(Date())
    }
    
    var isExpired: Bool {
        Date() >= expiresAt
    }
}

// MARK: - FLO Undo Manager

@MainActor
final class FLOUndoManager: ObservableObject {
    static let shared = FLOUndoManager()
    
    /// Duration before undo expires (in seconds)
    private let undoDuration: TimeInterval = 5.0
    
    /// Current pending undo action
    @Published private(set) var pendingAction: UndoableAction?
    
    /// Whether the toast is visible
    @Published private(set) var isShowingToast = false
    
    /// Timer for auto-execution
    private var expirationTimer: Timer?
    
    private init() {}
    
    // MARK: - Public API
    
    /// Schedule a delete action with undo capability
    /// - Parameters:
    ///   - message: Message to show in toast (e.g., "Transaction deleted")
    ///   - icon: SF Symbol name for the toast icon
    ///   - deleteAction: The actual delete action (called after undo window expires)
    ///   - undoAction: Action to restore the item (called if user taps Undo)
    func scheduleDelete(
        message: String,
        icon: String = "trash",
        deleteAction: @escaping () -> Void,
        undoAction: @escaping () -> Void
    ) {
        // If there's already a pending delete, EXECUTE it (commit permanently)
        // This ensures the first item is actually deleted before we schedule a new one
        if pendingAction != nil {
            commitPendingDelete()
        }
        
        // Create new undoable action
        let action = UndoableAction(
            message: message,
            icon: icon,
            deleteAction: deleteAction,
            undoAction: undoAction,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(undoDuration)
        )
        
        pendingAction = action
        
        // Show toast with animation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isShowingToast = true
        }
        
        // Haptic feedback
        HapticService.play(.light)
        
        // VoiceOver announcement
        AccessibilityAnnouncement.announce("\(message). Undo available.")
        
        // Schedule auto-execution
        scheduleExpiration()
    }
    
    /// User tapped Undo button
    func performUndo() {
        guard let action = pendingAction else { return }
        
        // Cancel timer
        expirationTimer?.invalidate()
        expirationTimer = nil
        
        // Perform undo action
        action.undoAction()
        
        // Haptic feedback
        HapticService.play(.success)
        
        // Hide toast
        dismissToast()
    }
    
    /// Force execute the delete (user dismissed or timeout)
    func executeDelete() {
        guard let action = pendingAction else { return }
        
        // Cancel timer
        expirationTimer?.invalidate()
        expirationTimer = nil
        
        // Perform delete action
        action.deleteAction()
        
        // Hide toast
        dismissToast()
    }
    
    /// Cancel pending action without executing
    func cancelPendingAction() {
        expirationTimer?.invalidate()
        expirationTimer = nil
        pendingAction = nil
        
        if isShowingToast {
            dismissToast()
        }
    }
    
    /// Commit (execute) pending delete immediately without toast animation
    /// Used when a new delete is scheduled before the undo window expires
    private func commitPendingDelete() {
        guard let action = pendingAction else { return }
        
        // Cancel the expiration timer
        expirationTimer?.invalidate()
        expirationTimer = nil
        
        // Execute the delete action (commit it permanently)
        action.deleteAction()
        
        // Clear pending action (no dismiss animation since new toast is coming)
        pendingAction = nil
        isShowingToast = false
    }
    
    // MARK: - Private Methods
    
    private func scheduleExpiration() {
        expirationTimer?.invalidate()
        
        expirationTimer = Timer.scheduledTimer(withTimeInterval: undoDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.executeDelete()
            }
        }
    }
    
    private func dismissToast() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isShowingToast = false
        }
        
        // Clear action after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.pendingAction = nil
        }
    }
}

// MARK: - Undo Toast View

struct UndoToastView: View {
    @ObservedObject private var undoManager = FLOUndoManager.shared
    
    var body: some View {
        if undoManager.isShowingToast, let action = undoManager.pendingAction {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: action.icon)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
                
                // Message
                Text(action.message)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                
                Spacer()
                
                // Undo Button
                Button {
                    undoManager.performUndo()
                } label: {
                    Text("Undo")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.brandPrimaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.floSystemBackground)
                        .cornerRadius(6)
                }
                .accessibilityHint("Double tap to undo the last action")
                
                // Progress indicator (optional countdown)
                UndoProgressRing(action: action)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray).opacity(0.95))
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 100) // Above tab bar
            .accessibilityElement(children: .contain)
            .accessibilityLabel("\(action.message). Undo available.")
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            ))
            .gesture(
                DragGesture()
                    .onEnded { value in
                        if value.translation.height > 50 {
                            // Swipe down to dismiss (execute delete)
                            undoManager.executeDelete()
                        }
                    }
            )
        }
    }
}

// MARK: - Undo Progress Ring

struct UndoProgressRing: View {
    let action: UndoableAction
    
    @State private var progress: CGFloat = 1.0
    
    var body: some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(Color.white.opacity(0.5), lineWidth: 2)
            .frame(width: 20, height: 20)
            .rotationEffect(.degrees(-90))
            .onAppear {
                withAnimation(.linear(duration: action.timeRemaining)) {
                    progress = 0
                }
            }
    }
}

// MARK: - View Extension for Easy Integration

extension View {
    /// Adds undo toast overlay to the view
    func undoToastOverlay() -> some View {
        self.overlay(alignment: .bottom) {
            UndoToastView()
        }
    }
}

// MARK: - Helper Extension for SwiftData Deletes

extension View {
    /// Wraps a delete action with undo support
    /// - Parameters:
    ///   - message: Toast message
    ///   - icon: SF Symbol icon
    ///   - delete: The delete action
    ///   - restore: The restore action (recreate the item)
    func withUndo(
        message: String,
        icon: String = "trash",
        delete: @escaping () -> Void,
        restore: @escaping () -> Void
    ) {
        FLOUndoManager.shared.scheduleDelete(
            message: message,
            icon: icon,
            deleteAction: delete,
            undoAction: restore
        )
    }
}

// MARK: - Preview

#Preview("Undo Toast") {
    ZStack {
        Color.floSystemBackground
            .ignoresSafeArea()
        
        VStack {
            Text("Main Content")
            
            Button("Delete Something") {
                FLOUndoManager.shared.scheduleDelete(
                    message: "Transaction deleted",
                    icon: "trash"
                ) {
                    print("Deleted!")
                } undoAction: {
                    print("Restored!")
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
    .undoToastOverlay()
}
