//
//  EarningsFormatStyle.swift
//  SalaryTimer
//
//  Created by Eric Feng on 10/30/26.
//

import Foundation

/// Turns the current date into the amount earned so far, for
/// `Text(.currentDate, format: EarningsFormatStyle(...))`.
///
/// Being a `DiscreteFormatStyle`, it tells the system exactly when the displayed cent changes,
/// so the text ticks on its own in Live Activities without the app pushing updates.
struct EarningsFormatStyle: DiscreteFormatStyle {
    var anchorDate: Date
    var startingAmount: Double
    var earningPerSecond: Double
    var symbol: String

    /// Small nudge so a requested update lands just past a cent boundary, not on it.
    private static let boundaryNudge: TimeInterval = 0.001

    func amount(at date: Date) -> Double {
        startingAmount + max(0, date.timeIntervalSince(anchorDate)) * earningPerSecond
    }

    /// Whole cents shown at `date`; floored so the display only ever counts up.
    private func cents(at date: Date) -> Double {
        (amount(at: date) * 100).rounded(.down)
    }

    /// Date at which the total reaches `cents`.
    private func date(reaching cents: Double) -> Date {
        anchorDate.addingTimeInterval((cents / 100 - startingAmount) / earningPerSecond)
    }

    func format(_ value: Date) -> String {
        Money.string(cents(at: value) / 100, symbol: symbol)
    }

    func discreteInput(after input: Date) -> Date? {
        guard earningPerSecond > 0 else { return nil }
        let next = date(reaching: cents(at: input) + 1).addingTimeInterval(Self.boundaryNudge)
        return max(next, input.addingTimeInterval(Self.boundaryNudge))
    }

    func discreteInput(before input: Date) -> Date? {
        guard earningPerSecond > 0 else { return nil }
        let start = date(reaching: cents(at: input))
        guard start > anchorDate else { return nil }
        return start.addingTimeInterval(-Self.boundaryNudge)
    }
}
