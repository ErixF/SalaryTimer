//
//  SettingsRouter.swift
//  SalaryTimer
//
//  Created by Eric Feng on 11/17/26.
//

import SwiftUI
import Observation

/// One row in Settings to jump to, and which field to focus once it's shown.
struct SettingsDestination: Equatable {
    var pane: SettingsView.Pane
    var field: SettingsView.Field? = nil

    static func income(focusing field: SettingsView.Field) -> SettingsDestination {
        SettingsDestination(pane: .income, field: field)
    }
}

/// Lets the Meter (tab page, sheet or Duo Home) open Settings on a specific row.
@MainActor
@Observable
final class SettingsRouter {
    /// Consumed by `SettingsView` when it appears, or right away if it's already visible.
    var pending: SettingsDestination?
    /// Bumped on every request so `RootTabView` presents Settings even when `pending` repeats.
    private(set) var requestID = 0

    func open(_ destination: SettingsDestination) {
        pending = destination
        requestID += 1
    }
}

extension RateCalculator.MissingIncomeField {
    var settingsField: SettingsView.Field {
        switch self {
        case .hourlyRate: .hourlyRate
        case .monthlyIncome: .monthlyIncome
        case .hoursPerDay: .hoursPerDay
        case .daysPerMonth: .daysPerMonth
        }
    }
}
