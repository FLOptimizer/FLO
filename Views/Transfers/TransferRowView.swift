//  TransferRowView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Transfer Row Component
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Reusable row component for displaying transfers in lists.
//
//  FEATURES:
//  ✅ Account flow visualization (From → To)
//  ✅ Transfer type badge with color
//  ✅ Amount display
//  ✅ Date formatting
//  ✅ Tax payment quarter indicator
//  ✅ Recurring indicator
//  ✅ Icon scale animation on appear
//  ✅ Full VoiceOver accessibility
//  ✅ Dynamic Type support
//

import SwiftUI
import SwiftData

struct TransferRowView: View {
    let transfer: Transfer
    
    @State private var iconAppeared = false
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 12) {
            // Transfer Type Icon
            transferIcon
            
            // Main Content
            VStack(alignment: .leading, spacing: 4) {
                // Account Flow
                accountFlowRow
                
                // Badges Row
                badgeRow
            }
            
            Spacer()
            
            // Amount
            amountColumn
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Double tap to edit, swipe for more options")
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                iconAppeared = true
            }
        }
    }
    
    // MARK: - Transfer Icon
    
    private var transferIcon: some View {
        ZStack {
            Circle()
                .fill(Color(flowHex: transfer.transferType.color).opacity(0.12))
                .frame(width: 44, height: 44)
            
            Image(systemName: transfer.transferType.icon)
                .font(.title3)
                .foregroundStyle(Color(flowHex: transfer.transferType.color))
        }
        .scaleEffect(iconAppeared ? 1 : 0.5)
        .accessibilityHidden(true)
    }
    
    // MARK: - Account Flow Row
    
    private var accountFlowRow: some View {
        HStack(spacing: 6) {
            // From Account
            Text(transfer.fromAccount?.name ?? "Unknown")
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            // Arrow
            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            // To Account
            Text(transfer.toAccount?.name ?? "Unknown")
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
    
    // MARK: - Badge Row
    
    private var badgeRow: some View {
        HStack(spacing: 6) {
            // Date
            Text(transfer.date, format: .dateTime.month(.abbreviated).day())
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // Transfer Type Badge
            transferTypeBadge
            
            // Tax Quarter Badge (if applicable)
            if transfer.transferType == .taxPayment, let quarter = transfer.taxQuarter {
                taxQuarterBadge(quarter: quarter, year: transfer.taxYear)
            }
            
            // Recurring Indicator
            if transfer.isFromRecurring {
                Image(systemName: "repeat")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Recurring transfer")
            }
            
            // Status Badge (if not completed)
            if transfer.status != .completed {
                statusBadge
            }
        }
    }
    
    private var transferTypeBadge: some View {
        Text(transfer.transferType.shortName)
            .font(.caption2)
            .fontWeight(.medium)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(flowHex: transfer.transferType.color).opacity(0.15))
            .foregroundStyle(Color(flowHex: transfer.transferType.color))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
    
    private func taxQuarterBadge(quarter: Int, year: Int?) -> some View {
        let yearStr = year.map { String($0 % 100) } ?? ""
        return Text("Q\(quarter)'\(yearStr)")
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color(flowHex: "#EF4444").opacity(0.12))
            .foregroundStyle(Color(flowHex: "#EF4444"))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
    
    private var statusBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: transfer.status.icon)
                .font(.caption2)
            Text(transfer.status.displayName)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Color(flowHex: transfer.status.color).opacity(0.12))
        .foregroundStyle(Color(flowHex: transfer.status.color))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
    
    // MARK: - Amount Column
    
    private var amountColumn: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(transfer.amount, format: .currency(code: "USD"))
                .font(.body)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(amountColor)
            
            // Show authority for tax payments
            if transfer.transferType == .taxPayment, let authority = transfer.taxAuthority {
                Text(authority.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var amountColor: Color {
        switch transfer.transferType {
        case .ownersDraw:
            return Color(flowHex: "#8B5CF6")  // Purple for draws
        case .capitalContribution:
            return Color(flowHex: "#14B8A6")  // Teal for contributions
        case .taxPayment:
            return Color(flowHex: "#EF4444")  // Red for tax
        case .debtPayment:
            return Color(flowHex: "#3B82F6")  // Blue for debt
        default:
            return .primary
        }
    }
    
    // MARK: - Accessibility
    
    private var accessibilityDescription: String {
        let amount = AccessibilityFormatters.spokenCurrency(transfer.amount)
        let date = AccessibilityFormatters.spokenDate(transfer.date)
        let from = transfer.fromAccount?.name ?? "unknown account"
        let to = transfer.toAccount?.name ?? "unknown account"
        let type = transfer.transferType.displayName
        
        var description = "\(type): \(amount) from \(from) to \(to), \(date)"
        
        if transfer.transferType == .taxPayment, let quarter = transfer.taxQuarter {
            description += ", Quarter \(quarter)"
            if let year = transfer.taxYear {
                description += " \(year)"
            }
        }
        
        if transfer.isFromRecurring {
            description += ", recurring"
        }
        
        if transfer.status != .completed {
            description += ", \(transfer.status.displayName)"
        }
        
        return description
    }
}

// MARK: - Compact Transfer Row (for dashboards)

struct TransferRowCompact: View {
    let transfer: Transfer
    
    var body: some View {
        HStack(spacing: 10) {
            // Icon
            Image(systemName: transfer.transferType.icon)
                .font(.caption)
                .foregroundStyle(Color(flowHex: transfer.transferType.color))
                .frame(width: 24, height: 24)
                .background(Color(flowHex: transfer.transferType.color).opacity(0.12))
                .clipShape(Circle())
            
            // Description
            VStack(alignment: .leading, spacing: 2) {
                Text(transfer.displayDescription)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(transfer.transferType.shortName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Amount
            Text(transfer.amount, format: .currency(code: "USD"))
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(transfer.transferType.displayName): \(transfer.formattedAmount) from \(transfer.fromAccount?.name ?? "unknown") to \(transfer.toAccount?.name ?? "unknown")")
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Full Row") {
    List {
        TransferRowView(transfer: .previewOwnersDraw)
        TransferRowView(transfer: .previewDebtPayment)
        TransferRowView(transfer: .previewTaxPayment)
        TransferRowView(transfer: .previewInternal)
    }
    .modelContainer(for: Transfer.self, inMemory: true)
}

#Preview("Compact Row") {
    List {
        TransferRowCompact(transfer: .previewOwnersDraw)
        TransferRowCompact(transfer: .previewTaxPayment)
    }
    .modelContainer(for: Transfer.self, inMemory: true)
}
#endif
