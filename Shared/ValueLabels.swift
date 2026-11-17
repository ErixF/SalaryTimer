//
//  ValueLabels.swift
//  SalaryTimer
//
//  Created by Eric Feng on 11/17/26.
//

import Foundation

/// Words instead of raw zeros for empty values, shared by the app and the widget extension.
enum ValueLabels {
    static let notSet = "Not set"
    static let none = "None"
    static let noRate = "No rate set"
    static let noIncome = "No income set"
    static let noDeductions = "No deductions"
    static let noGoal = "No goal"
    static let noSessionsYet = "No sessions yet"

    /// `$60.00/hr`, or "No rate set".
    static func hourlyRate(_ hourly: Double, symbol: String) -> String {
        guard hourly > 0 else { return noRate }
        return "\(Money.string(hourly, symbol: symbol))/hr"
    }

    /// `$60.00/hr ≈ $0.0167/sec`, or "No rate set".
    static func rateSummary(hourly: Double, symbol: String) -> String {
        guard hourly > 0 else { return noRate }
        return "\(hourlyRate(hourly, symbol: symbol)) ≈ \(Money.string(hourly / 3600, symbol: symbol, fractionDigits: 4...4))/sec"
    }

    /// `≈ $0.0167/sec`, or "No rate set".
    static func perSecond(_ value: Double, symbol: String) -> String {
        guard value > 0 else { return noRate }
        return "≈ \(Money.string(value, symbol: symbol, fractionDigits: 4...4))/sec"
    }

    /// "20% deductions", or "No deductions".
    static func deductions(_ percent: Double) -> String {
        guard percent > 0 else { return noDeductions }
        return "\(percent.formatted(.number.precision(.fractionLength(0...2))))% deductions"
    }

    /// "No sessions yet", "1 session", "3 sessions".
    static func sessions(_ count: Int) -> String {
        switch count {
        case ...0: noSessionsYet
        case 1: "1 session"
        default: "\(count) sessions"
        }
    }

    /// "Goal $400", or "No goal".
    static func goal(_ goal: Double?, symbol: String) -> String {
        guard let goal, goal > 0 else { return noGoal }
        return "Goal \(Money.string(goal, symbol: symbol, fractionDigits: 0...2))"
    }
}
