//  BusinessSwitcherView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Multi-Business Switcher
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Compact toolbar menu for switching active business context.
//  Used in DashboardView and ReportsView toolbars.
//

import SwiftUI
import SwiftData

struct BusinessSwitcherView: View {
    @Query(
        filter: #Predicate<BusinessProfile> { $0.isActive },
        sort: \BusinessProfile.sortOrder
    )
    private var businesses: [BusinessProfile]

    private var manager = ActiveBusinessManager.shared

    var body: some View {
        if businesses.count > 1 {
            Menu {
                Button {
                    manager.selectAllBusinesses()
                } label: {
                    Label("All Businesses", systemImage: "building.2")
                }

                Divider()

                ForEach(businesses) { business in
                    Button {
                        manager.selectBusiness(business)
                    } label: {
                        Label {
                            HStack {
                                Text(business.businessName)
                                if business.isPrimary {
                                    Text("Primary")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } icon: {
                            Image(systemName: business.displayIcon)
                        }
                    }
                }

                Divider()

                Button {
                    manager.selectPersonal()
                } label: {
                    Label("Personal", systemImage: "person.fill")
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: manager.displayIcon)
                    Text(manager.displayName)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .font(.subheadline.weight(.medium))
            }
        }
    }
}

#Preview {
    BusinessSwitcherView()
        .modelContainer(ModelContainer.preview())
}
