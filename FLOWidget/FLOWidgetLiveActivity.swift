//  FLOWidgetLiveActivity.swift
//  FLO - Finance Ledger OptimizerWidget
//
//
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct FLOWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct FLOWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FLOWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension FLOWidgetAttributes {
    fileprivate static var preview: FLOWidgetAttributes {
        FLOWidgetAttributes(name: "World")
    }
}

extension FLOWidgetAttributes.ContentState {
    fileprivate static var smiley: FLOWidgetAttributes.ContentState {
        FLOWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: FLOWidgetAttributes.ContentState {
         FLOWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: FLOWidgetAttributes.preview) {
   FLOWidgetLiveActivity()
} contentStates: {
    FLOWidgetAttributes.ContentState.smiley
    FLOWidgetAttributes.ContentState.starEyes
}
