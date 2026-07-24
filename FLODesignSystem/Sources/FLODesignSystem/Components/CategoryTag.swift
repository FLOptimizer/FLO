//  CategoryTag.swift
//  FLODesignSystem
//
//  Colored pill tag displaying a transaction/budget category.
//  Bold, uppercase, 9pt with category-specific background color.
//  Inspired by Copilot Money's category pill tags.
//
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI

/// A colored pill displaying an expense/income category name.
///
/// Usage:
/// ```swift
/// CategoryTag(category: "Groceries")
/// CategoryTag(category: "Dining Out")
/// CategoryTag(category: "Coffee")  // Special: gold text on brown
/// ```
public struct CategoryTag: View {
    let category: String
    let size: TagSize

    public enum TagSize {
        case standard   // 9pt — list rows
        case compact    // 8pt — tight spaces
        case large      // 11pt — detail views

        var fontSize: CGFloat {
            switch self {
            case .compact:  return 8
            case .standard: return 9
            case .large:    return 11
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .compact:  return 6
            case .standard: return 8
            case .large:    return 10
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .compact:  return 1
            case .standard: return 2
            case .large:    return 3
            }
        }
    }

    public init(category: String, size: TagSize = .standard) {
        self.category = category
        self.size = size
    }

    public var body: some View {
        Text(category)
            .font(.system(size: size.fontSize, weight: .bold))
            .textCase(.uppercase)
            .tracking(0.5)
            .foregroundStyle(FLOCategoryColors.textColor(for: category))
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(FLOCategoryColors.color(for: category))
            .clipShape(RoundedRectangle(cornerRadius: FLOSpacing.tagRadius))
            .accessibilityLabel("Category: \(category)")
    }
}

#if DEBUG
#Preview("Category Tags") {
    VStack(alignment: .leading, spacing: 8) {
        CategoryTag(category: "Groceries")
        CategoryTag(category: "Dining Out")
        CategoryTag(category: "Coffee")
        CategoryTag(category: "Software & Tools")
        CategoryTag(category: "Transportation")
        CategoryTag(category: "Entertainment")
        CategoryTag(category: "Shopping")
        CategoryTag(category: "Client Payment")
        CategoryTag(category: "Housing")
        CategoryTag(category: "Office Supplies")
        CategoryTag(category: "Health")
        CategoryTag(category: "Utilities")
    }
    .padding()
    .background(Color(hex: "07070D"))
}

#Preview("Tag Sizes") {
    VStack(alignment: .leading, spacing: 8) {
        CategoryTag(category: "Groceries", size: .compact)
        CategoryTag(category: "Groceries", size: .standard)
        CategoryTag(category: "Groceries", size: .large)
    }
    .padding()
    .background(Color(hex: "07070D"))
}
#endif
