//  FLOWatchComplicationBundle.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Watch Face Complications Bundle
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  TARGET MEMBERSHIP:
//  ✅ FLOWatchComplications (watchOS widget extension — has @main)
//
//  COMPLICATIONS INCLUDED:
//  1. SpendingSummaryComplication — Today's spending total (all tiers)
//  2. TaxDeadlineComplication — Days until quarterly deadline (Premium+)
//  3. MileageComplication — Active trip or today's miles (Premium+)
//
//  DATA SOURCE:
//  Complications read from App Group UserDefaults (shared with Watch app).
//  The Watch app writes complication data from WatchSnapshot on each update.
//  WidgetKit refreshes timelines based on these writes.
//

import WidgetKit
import SwiftUI

@main
struct FLOWatchComplicationBundle: WidgetBundle {
    var body: some Widget {
        SpendingSummaryComplication()
        TaxDeadlineComplication()
        MileageComplication()
    }
}
