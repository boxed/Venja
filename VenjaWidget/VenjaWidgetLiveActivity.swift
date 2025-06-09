//
//  VenjaWidgetLiveActivity.swift
//  VenjaWidget
//
//  Created by Anders Hovmöller on 2025-06-08.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct VenjaWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct VenjaWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: VenjaWidgetAttributes.self) { context in
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

extension VenjaWidgetAttributes {
    fileprivate static var preview: VenjaWidgetAttributes {
        VenjaWidgetAttributes(name: "World")
    }
}

extension VenjaWidgetAttributes.ContentState {
    fileprivate static var smiley: VenjaWidgetAttributes.ContentState {
        VenjaWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: VenjaWidgetAttributes.ContentState {
         VenjaWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: VenjaWidgetAttributes.preview) {
   VenjaWidgetLiveActivity()
} contentStates: {
    VenjaWidgetAttributes.ContentState.smiley
    VenjaWidgetAttributes.ContentState.starEyes
}
