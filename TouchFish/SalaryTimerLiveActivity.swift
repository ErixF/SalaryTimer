//
//  SalaryTimerLiveActivity.swift
//  SalaryTimer
//
//  Created by Eric Feng on 5/22/25.
//


import WidgetKit
import SwiftUI
import ActivityKit

struct SalaryTimerLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: SalaryTimerAttributes.self) { context in
      // Lock screen/banner presentation
      VStack {
        Text(context.attributes.currencyCode)
          .font(.headline)
        Text(context.state.totalEarned, format: .currency(code: context.attributes.currencyCode))
          .font(.largeTitle)
          .monospacedDigit()
      }
      .padding()
      .activityBackgroundTint(Color.black)
      .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.center) {
          Text(context.state.totalEarned, format: .currency(code: context.attributes.currencyCode))
            .font(.title2)
            .monospacedDigit()
        }
      } compactLeading: {
        Text(context.state.totalEarned, format: .currency(code: context.attributes.currencyCode))
          .font(.body)
          .monospacedDigit()
      } compactTrailing: {
        EmptyView()
      } minimal: {
        Text(context.state.totalEarned, format: .currency(code: context.attributes.currencyCode))
          .font(.caption)
          .monospacedDigit()
      }
      .widgetURL(URL(string: "salarytimer://live"))
      .keylineTint(Color.red)
    }
  }
}


extension SalaryTimerAttributes {
    fileprivate static var preview: SalaryTimerAttributes {
        SalaryTimerAttributes()
    }
}


#Preview("Notification", as: .content, using: SalaryTimerAttributes.preview) {
    SalaryTimerLiveActivity()
} contentStates: {
    // Provide a sample totalEarned value for preview
    SalaryTimerAttributes.ContentState(totalEarned: 123.45)
}
