//
//  StructifyWidgetLiveActivity.swift
//  StructifyWidget
//
//  Created by Sam Manh Cuong on 18/3/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct StructifyWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct StructifyWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StructifyWidgetAttributes.self) { context in
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

extension StructifyWidgetAttributes {
    fileprivate static var preview: StructifyWidgetAttributes {
        StructifyWidgetAttributes(name: "World")
    }
}

extension StructifyWidgetAttributes.ContentState {
    fileprivate static var smiley: StructifyWidgetAttributes.ContentState {
        StructifyWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: StructifyWidgetAttributes.ContentState {
         StructifyWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: StructifyWidgetAttributes.preview) {
   StructifyWidgetLiveActivity()
} contentStates: {
    StructifyWidgetAttributes.ContentState.smiley
    StructifyWidgetAttributes.ContentState.starEyes
}
