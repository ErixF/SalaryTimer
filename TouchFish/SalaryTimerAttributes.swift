//
//  SalaryTimerAttributes.swift
//  SalaryTimer
//
//  Created by Eric Feng on 5/24/25.
//

import ActivityKit
import Foundation

struct SalaryTimerAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var sessionStartDate: Date
    var amountAnchorDate: Date
    var startingAmount: Double
    var earningPerSecond: Double
    /// Set while the meter is paused; the activity shows frozen values.
    var pausedAt: Date? = nil
  }

  var currencyCode: String = "USD"
}
