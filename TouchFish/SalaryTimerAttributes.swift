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
  }

  var currencyCode: String = "USD"
}
