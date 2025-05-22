//
//  TouchFishLiveActivity.swift
//  TouchFish
//
//  Created by Eric Feng on 5/22/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct TouchFishAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct TouchFishLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TouchFishAttributes.self) { context in
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

extension TouchFishAttributes {
    fileprivate static var preview: TouchFishAttributes {
        TouchFishAttributes(name: "World")
    }
}

extension TouchFishAttributes.ContentState {
    fileprivate static var smiley: TouchFishAttributes.ContentState {
        TouchFishAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: TouchFishAttributes.ContentState {
         TouchFishAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: TouchFishAttributes.preview) {
   TouchFishLiveActivity()
} contentStates: {
    TouchFishAttributes.ContentState.smiley
    TouchFishAttributes.ContentState.starEyes
}
