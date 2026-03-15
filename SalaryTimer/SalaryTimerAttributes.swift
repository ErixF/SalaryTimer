//
//  SalaryTimerAttributes.swift
//  SalaryTimer
//
//  Created by Eric Feng on 5/24/25.
//

import ActivityKit

struct SalaryTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var startDate: Date
        var startingAmount: Double
        var earningPerSecond: Double
    }

    var currencyCode: String = "USD"
}
