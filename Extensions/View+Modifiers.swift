//  View_Modifiers.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.2 - Dynamic Type verification: lineLimit + minimumScaleFactor on all text
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v2.2 - Dynamic Type Verification:
//  ✅ FIXED: floLoading message text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: floEmptyState title text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: floEmptyState message text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: floEmptyState action button text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: floBadge count text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Preview card labels missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Preview button labels missing lineLimit + minimumScaleFactor
//  ✅ VERIFIED: Text modifiers (floSectionHeader, floCaption, etc.) are applied TO views, not inside modifier bodies
//
//  CHANGES v2.1:
//  ✅ Removed duplicate brandPrimary (exists in Color_Extensions.swift)
//  ✅ Removed duplicate ShimmerModifier (exists in AnimationService.swift)
//  ✅ Removed floShimmer (already defined in AnimationService.swift)
//
//  CHANGES v2.0:
//  ✅ Added 20+ reusable FLO-prefixed modifiers
//  ✅ Card styles (floCard, floOutlineCard, floGroupedCard, floGlassCard)
//  ✅ Button styles (floPrimaryButton, floSecondaryButton, floDestructiveButton, floPillButton)
//  ✅ Text styles (floLargeTitle, floSectionHeader, floCaption, floCurrency)
//  ✅ Layout helpers (floFullWidth, floCentered, floSafeArea)
//  ✅ Interactive states (floDisabled, floLoading, floPressable)
//  ✅ Empty state overlay (floEmptyState)
//  ✅ Accessibility modifiers (floAccessibleButton, floAccessibleCard)
//  ✅ Maintained backward compatibility with existing modifiers
//
//  PURPOSE:
//  Provides consistent styling across the app
//  Reduces code duplication in views
//  Ensures accessibility compliance
//  Makes UI changes easy to implement globally
//
//  USAGE:
//  Text("Save").floPrimaryButton()
//  VStack { ... }.floCard()
//  Text("Section").floSectionHeader()
//  someView.floLoading(isLoading)
//
//  NOTE: This file depends on:
//  - Color_Extensions.swift (for Color.brandPrimary)
//  - AnimationService.swift (for floShimmer modifier)
//

import SwiftUI

// MARK: - Card Styles

extension View {
    
    /// Standard FLO card with shadow
    /// Use for dashboard cards, list items, content containers
    func floCard() -> some View {
        self
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
    
    /// Colored card with custom background
    /// Use for highlighted content, category cards
    func floCard(background: Color) -> some View {
        self
            .padding()
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    /// Outline card (no shadow, border only)
    /// Use for selection states, secondary content
    func floOutlineCard(borderColor: Color = .secondary.opacity(0.3)) -> some View {
        self
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 1)
            )
    }
    
    /// Grouped card for list sections
    /// Use inside grouped lists, settings sections
    func floGroupedCard() -> some View {
        self
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    /// Glass morphism card effect
    /// Use for overlays, floating UI elements
    func floGlassCard() -> some View {
        self
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    /// Accent-bordered card (teal border)
    /// Use for active/selected states, premium features
    func floAccentCard() -> some View {
        self
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.brandPrimary, lineWidth: 2)
            )
            .shadow(color: Color.brandPrimary.opacity(0.2), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Button Styles

extension View {
    
    /// Primary action button (teal background)
    /// Use for main CTAs: Save, Continue, Add
    func floPrimaryButton() -> some View {
        self
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.brandPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    /// Secondary action button (teal tint, no fill)
    /// Use for secondary actions: Cancel, Edit, View All
    func floSecondaryButton() -> some View {
        self
            .font(.headline)
            .foregroundStyle(Color.brandPrimaryText)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.brandPrimary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    /// Destructive button (red)
    /// Use for delete, remove, cancel subscription
    func floDestructiveButton() -> some View {
        self
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    /// Small pill button
    /// Use for tags, filters, quick actions
    func floPillButton(color: Color = .brandPrimary) -> some View {
        self
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(color)
            .clipShape(Capsule())
    }
    
    /// Outline pill button
    /// Use for filter chips, toggleable options
    func floOutlinePillButton(color: Color = .brandPrimary, isSelected: Bool = false) -> some View {
        self
            .font(.subheadline.weight(.medium))
            .foregroundStyle(isSelected ? .white : color)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? color : Color.clear)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(color, lineWidth: 1.5)
            )
    }
    
    /// Icon button with circle background
    /// Use for toolbar actions, floating buttons
    func floIconButton(color: Color = .brandPrimary, size: CGFloat = 44) -> some View {
        self
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color)
            .clipShape(Circle())
            .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Text Styles

extension View {
    
    /// Large title style
    /// Use for screen titles, hero text
    func floLargeTitle() -> some View {
        self
            .font(.largeTitle)
            .fontWeight(.bold)
    }
    
    /// Section header style (uppercase, secondary color)
    /// Use for list section headers, form sections
    func floSectionHeader() -> some View {
        self
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
    
    /// Caption/helper text
    /// Use for descriptions, timestamps, hints
    func floCaption() -> some View {
        self
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    
    /// Currency display (large, colored based on value)
    /// Use for balance displays, transaction amounts
    func floCurrency(isPositive: Bool) -> some View {
        self
            .font(.title2.weight(.bold).monospacedDigit())
            .foregroundStyle(isPositive ? .green : .red)
    }
    
    /// Neutral currency display (no color)
    /// Use for totals, summaries where direction doesn't matter
    func floCurrencyNeutral() -> some View {
        self
            .font(.title2.weight(.bold).monospacedDigit())
            .foregroundStyle(.primary)
    }
    
    /// Small monospaced text for IDs, codes
    /// Use for transaction IDs, invoice numbers
    func floMonoCode() -> some View {
        self
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
    }
}

// MARK: - Layout Helpers

extension View {
    
    /// Full width with horizontal padding
    /// Use for buttons, cards that need to span the width
    func floFullWidth(padding: CGFloat = 16) -> some View {
        self
            .frame(maxWidth: .infinity)
            .padding(.horizontal, padding)
    }
    
    /// Centered content
    /// Use for empty states, loading views
    func floCentered() -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .multilineTextAlignment(.center)
    }
    
    /// Safe area padding
    /// Use for bottom content to avoid home indicator
    func floSafeArea() -> some View {
        self
            .padding(.horizontal)
            .padding(.bottom, 20)
    }
    
    /// Standard horizontal padding
    func floHorizontalPadding(_ padding: CGFloat = 16) -> some View {
        self.padding(.horizontal, padding)
    }
    
    /// Standard vertical spacing
    func floVerticalSpacing(_ spacing: CGFloat = 12) -> some View {
        self.padding(.vertical, spacing)
    }
}

// MARK: - Interactive States

extension View {
    
    /// Disabled state styling
    /// Use for buttons/controls that are temporarily unavailable
    func floDisabled(_ isDisabled: Bool) -> some View {
        self
            .opacity(isDisabled ? 0.5 : 1.0)
            .allowsHitTesting(!isDisabled)
    }
    
    /// Loading overlay
    /// Use while waiting for async operations
    func floLoading(_ isLoading: Bool, message: String? = nil) -> some View {
        self
            .overlay {
                if isLoading {
                    ZStack {
                        Color(.systemBackground).opacity(0.8)
                        VStack(spacing: 12) {
                            ProgressView()
                            if let message = message {
                                Text(message)
                                    .font(.caption)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.7)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .allowsHitTesting(!isLoading)
    }
    
    // NOTE: floShimmer is defined in AnimationService.swift
    // Use: .floShimmer(isActive: true) for shimmer loading effects
    
    /// Press state for interactive elements
    /// Use for custom buttons, cards
    func floPressable(isPressed: Bool, scale: CGFloat = 0.97) -> some View {
        self
            .scaleEffect(isPressed ? scale : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }
}

// MARK: - Empty State

extension View {
    
    /// Empty state overlay
    /// Use when lists/collections are empty
    func floEmptyState(
        isEmpty: Bool,
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        self.overlay {
            if isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: icon)
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    
                    Text(title)
                        .font(.headline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    
                    Text(message)
                        .font(.subheadline)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    if let actionTitle = actionTitle, let action = action {
                        Button(action: action) {
                            Text(actionTitle)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .floPillButton()
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(32)
            }
        }
    }
}

// MARK: - Accessibility Helpers

extension View {
    
    /// Ensures button meets minimum tap target (44x44)
    /// Use for small interactive elements
    func floAccessibleButton() -> some View {
        self
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
    }
    
    /// Accessible card with combined label
    /// Groups child elements for VoiceOver
    func floAccessibleCard(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
    }
    
    /// Hides decorative elements from VoiceOver
    func floAccessibilityHidden() -> some View {
        self.accessibilityHidden(true)
    }
}

// MARK: - Badge Modifiers

extension View {
    
    /// Notification badge overlay
    /// Use for unread counts, alerts
    func floBadge(_ count: Int, color: Color = .red) -> some View {
        self.overlay(alignment: .topTrailing) {
            if count > 0 {
                Text(count > 99 ? "99+" : "\(count)")
                    .font(.caption2.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color)
                    .clipShape(Capsule())
                    .offset(x: 8, y: -8)
            }
        }
    }
    
    /// Status dot indicator
    /// Use for online/offline, sync status
    func floStatusDot(color: Color, size: CGFloat = 8) -> some View {
        self.overlay(alignment: .topTrailing) {
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .offset(x: 2, y: -2)
        }
    }
}

// MARK: - Conditional Modifiers

extension View {
    
    /// Apply modifier conditionally
    @ViewBuilder
    func floIf<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Apply modifier based on optional value
    @ViewBuilder
    func floIfLet<T, Content: View>(_ value: T?, transform: (Self, T) -> Content) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }
}

// MARK: - Legacy Modifiers (Backward Compatibility)

extension View {
    /// Legacy card modifier - use floCard() for new code
    func appCard() -> some View {
        self
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    /// Legacy section header - use floSectionHeader() for new code
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
    
    /// Legacy large button - use floPrimaryButton() for new code
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

// MARK: - Preview

#Preview("Card Styles") {
    ScrollView {
        VStack(spacing: 20) {
            Text("floCard()")
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .floCard()
            
            Text("floOutlineCard()")
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .floOutlineCard()
            
            Text("floGlassCard()")
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .floGlassCard()
            
            Text("floAccentCard()")
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .floAccentCard()
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Button Styles") {
    VStack(spacing: 16) {
        Text("Primary Button")
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .floPrimaryButton()
        
        Text("Secondary Button")
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .floSecondaryButton()
        
        Text("Destructive Button")
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .floDestructiveButton()
        
        HStack {
            Text("Pill")
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .floPillButton()
            Text("Outline")
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .floOutlinePillButton()
            Text("Selected")
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .floOutlinePillButton(isSelected: true)
        }
        
        Image(systemName: "plus")
            .floIconButton()
    }
    .padding()
}

#Preview("Empty State") {
    Color.clear
        .floEmptyState(
            isEmpty: true,
            icon: "doc.text",
            title: "No Transactions",
            message: "Add your first transaction to get started",
            actionTitle: "Add Transaction"
        ) {
            print("Add tapped")
        }
}
