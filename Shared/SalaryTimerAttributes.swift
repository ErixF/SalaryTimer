//
//  SalaryTimerAttributes.swift
//  SalaryTimer
//
//  Created by Eric Feng on 5/24/25.
//

import ActivityKit
import Foundation

/// Live Activity data, shared by the app and the TouchFish widget extension.
struct SalaryTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Effective start (now − elapsed), so a counting-up timer shows total elapsed time.
        var sessionStartDate: Date
        var amountAnchorDate: Date
        var startingAmount: Double
        var earningPerSecond: Double
        /// Set while the meter is paused; the activity shows frozen values.
        var pausedAt: Date? = nil
        var currencySymbol: String = Money.defaultSymbol
    }
}

extension SalaryTimerAttributes.ContentState {
    var isPaused: Bool { pausedAt != nil }

    /// Amount at `date`, frozen at the pause point while paused. Live Activities can only tick
    /// Apple's built-in date formats (custom FormatStyles render as placeholders), so this is
    /// evaluated whenever the app pushes an update.
    func amount(at date: Date) -> Double {
        let end = pausedAt ?? date
        return startingAmount + max(0, end.timeIntervalSince(amountAnchorDate)) * earningPerSecond
    }
}
