//
//  TouchFishAttributes.swift
//  SalaryTimer
//
//  Created by Eric Feng on 5/24/25.
//

import ActivityKit

struct SalaryTimerAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    // the only piece of data we’ll display
    var totalEarned: Double
  }

  // you can put any fixed metadata here (e.g. currency symbol)
  var currencyCode: String = "USD"
}
