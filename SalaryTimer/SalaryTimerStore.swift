//
//  SalaryTimerStore.swift
//  SalaryTimer
//
//  Created by Eric Feng on 10/30/26.
//

import Foundation
import SwiftData
import ActivityKit
import Observation

// MARK: - Meter state

enum MeterState: String {
    case idle
    case running
    case paused
}

// MARK: - Rate math

/// Pure rate math shared by the Meter and Profile tabs.
struct RateCalculator {
    var incomeType: Int
    var hourlyRate: Double
    var monthlyIncome: Double
    var hoursPerDay: Double
    var daysPerMonth: Double
    /// `nil` when the Deductions field is blank.
    var deductionPercent: Double?

    init(
        incomeType: Int,
        hourlyRateText: String,
        monthlyIncomeText: String,
        hoursPerDayText: String,
        daysPerMonthText: String,
        deductionText: String
    ) {
        self.incomeType = incomeType
        self.hourlyRate = max(0, Double(hourlyRateText) ?? 0)
        self.monthlyIncome = max(0, Double(monthlyIncomeText) ?? 0)
        self.hoursPerDay = max(0, Double(hoursPerDayText) ?? 0)
        self.daysPerMonth = max(0, Double(daysPerMonthText) ?? 0)
        self.deductionPercent = Double(deductionText.trimmingCharacters(in: .whitespaces))
    }

    /// Reads the values the Profile tab stores in `@AppStorage`.
    static func fromDefaults(_ defaults: UserDefaults = .standard) -> RateCalculator {
        RateCalculator(
            incomeType: defaults.integer(forKey: ProfileKeys.incomeType),
            hourlyRateText: defaults.string(forKey: ProfileKeys.hourlyRate) ?? "",
            monthlyIncomeText: defaults.string(forKey: ProfileKeys.monthlyIncome) ?? "",
            hoursPerDayText: defaults.string(forKey: ProfileKeys.hoursPerDay) ?? "",
            daysPerMonthText: defaults.string(forKey: ProfileKeys.daysPerMonth) ?? "",
            deductionText: defaults.string(forKey: ProfileKeys.taxRate) ?? ""
        )
    }

    var hasDeductions: Bool { deductionPercent != nil }

    /// Deduction clamped to 0–100%. Blank counts as 0%.
    var deduction: Double { min(100, max(0, deductionPercent ?? 0)) }

    var monthlyHours: Double { hoursPerDay * daysPerMonth }

    var grossHourly: Double {
        if incomeType == 0 { return hourlyRate }
        return monthlyHours > 0 ? monthlyIncome / monthlyHours : 0
    }

    var netHourly: Double { grossHourly * (1 - deduction / 100) }
    var grossPerSecond: Double { grossHourly / 3600 }
    var netPerSecond: Double { netHourly / 3600 }
}

enum ProfileKeys {
    static let incomeType = "profile.incomeType"
    static let hourlyRate = "profile.hourlyRate"
    static let monthlyIncome = "profile.monthlyIncome"
    static let taxRate = "profile.taxRate"
    static let hoursPerDay = "profile.hoursPerDay"
    static let daysPerMonth = "profile.daysPerMonth"
    static let currencySymbol = "profile.currencySymbol"
    static let sessionGoal = "profile.sessionGoal"
    /// iPhone Duo "Alternative Look": Settings as a sheet on wide screens and the combined Home.
    static let alternativeLook = "display.alternativeLook"
}

/// Optional per-session earnings goal from Profile. Blank or zero means no goal.
enum SessionGoal {
    static func amount(from text: String) -> Double? {
        guard let value = Double(text.trimmingCharacters(in: .whitespaces)), value > 0 else { return nil }
        return value
    }

    static func current(_ defaults: UserDefaults = .standard) -> Double? {
        amount(from: defaults.string(forKey: ProfileKeys.sessionGoal) ?? "")
    }
}

// MARK: - Store

/// Owns the meter session. A session is a series of segments (one per Start/Resume);
/// each pause locks in that segment's time and money, so a rate edited while paused
/// only applies from the next Resume. Everything is derived from timestamps and
/// persisted, so the session survives backgrounding and app termination.
@MainActor
@Observable
final class SalaryTimerStore {
    private(set) var state: MeterState = .idle
    private(set) var sessionStartDate: Date?
    private(set) var segmentStartDate: Date?
    private(set) var lockedDuration: TimeInterval = 0
    private(set) var lockedNet: Double = 0
    private(set) var lockedGross: Double = 0
    /// Rates captured when the current segment began. Profile is locked while running.
    private(set) var segmentNetPerSecond: Double = 0
    private(set) var segmentGrossPerSecond: Double = 0

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var liveActivity: Activity<SalaryTimerAttributes>?
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    private let liveActivityRefreshInterval: Duration = .seconds(15)

    var isRunning: Bool { state == .running }

    init(defaults: UserDefaults = .standard, restoresSession: Bool = true) {
        self.defaults = defaults
        if restoresSession {
            restore()
            reconcileLiveActivities()
        }
    }

    // MARK: Derived values

    func elapsed(at now: Date = .now) -> TimeInterval {
        guard state == .running, let segmentStartDate else { return lockedDuration }
        return lockedDuration + max(0, now.timeIntervalSince(segmentStartDate))
    }

    func netEarned(at now: Date = .now) -> Double {
        guard state == .running, let segmentStartDate else { return lockedNet }
        return lockedNet + max(0, now.timeIntervalSince(segmentStartDate)) * segmentNetPerSecond
    }

    func grossEarned(at now: Date = .now) -> Double {
        guard state == .running, let segmentStartDate else { return lockedGross }
        return lockedGross + max(0, now.timeIntervalSince(segmentStartDate)) * segmentGrossPerSecond
    }

    // MARK: Transitions

    /// Idle → Running, or Paused → Running (resume). Captures the current Profile rate.
    func start(at now: Date = .now) {
        guard state != .running else { return }
        let rates = RateCalculator.fromDefaults(defaults)
        if state == .idle {
            sessionStartDate = now
        }
        segmentStartDate = now
        segmentNetPerSecond = rates.netPerSecond
        segmentGrossPerSecond = rates.grossPerSecond
        state = .running
        persist()
        startOrUpdateLiveActivity(at: now)
        startRefreshLoop()
    }

    /// Running → Paused. Locks in the current segment.
    func pause(at now: Date = .now) {
        guard state == .running else { return }
        lockedDuration = elapsed(at: now)
        lockedNet = netEarned(at: now)
        lockedGross = grossEarned(at: now)
        segmentStartDate = nil
        state = .paused
        persist()
        stopRefreshLoop()
        updateLiveActivity(at: now)
    }

    /// Paused → Idle. Saves the session to Records and returns it, or `nil` if nothing was metered.
    @discardableResult
    func archiveAndReset(in context: ModelContext, at now: Date = .now) -> SalarySession? {
        guard state == .paused else { return nil }
        let session = makeSession(endDate: now)
        if let session {
            context.insert(session)
        }
        clearSession()
        return session
    }

    /// Hidden full reset: saves any metered time, then returns to Idle and ends all Live Activities.
    func resetAll(in context: ModelContext, at now: Date = .now) {
        if state == .running { pause(at: now) }
        if let session = makeSession(endDate: now) {
            context.insert(session)
        }
        clearSession()
        endAllLiveActivities()
    }

    private func makeSession(endDate: Date) -> SalarySession? {
        guard lockedDuration > 0 else { return nil }
        return SalarySession(
            endDate: endDate,
            totalEarned: lockedNet,
            duration: lockedDuration,
            unitPrice: lockedNet / lockedDuration,
            startDate: sessionStartDate,
            grossEarned: lockedGross
        )
    }

    private func clearSession() {
        state = .idle
        sessionStartDate = nil
        segmentStartDate = nil
        lockedDuration = 0
        lockedNet = 0
        lockedGross = 0
        segmentNetPerSecond = 0
        segmentGrossPerSecond = 0
        persist()
        stopRefreshLoop()
        endLiveActivity()
    }

    // MARK: Persistence

    private enum Keys {
        static let state = "meter.state"
        static let sessionStart = "meter.sessionStart"
        static let segmentStart = "meter.segmentStart"
        static let lockedDuration = "meter.lockedDuration"
        static let lockedNet = "meter.lockedNet"
        static let lockedGross = "meter.lockedGross"
        static let segmentNet = "meter.segmentNetPerSecond"
        static let segmentGross = "meter.segmentGrossPerSecond"
    }

    private func persist() {
        defaults.set(state.rawValue, forKey: Keys.state)
        defaults.set(sessionStartDate, forKey: Keys.sessionStart)
        defaults.set(segmentStartDate, forKey: Keys.segmentStart)
        defaults.set(lockedDuration, forKey: Keys.lockedDuration)
        defaults.set(lockedNet, forKey: Keys.lockedNet)
        defaults.set(lockedGross, forKey: Keys.lockedGross)
        defaults.set(segmentNetPerSecond, forKey: Keys.segmentNet)
        defaults.set(segmentGrossPerSecond, forKey: Keys.segmentGross)
    }

    private func restore() {
        let restored = MeterState(rawValue: defaults.string(forKey: Keys.state) ?? "") ?? .idle
        sessionStartDate = defaults.object(forKey: Keys.sessionStart) as? Date
        segmentStartDate = defaults.object(forKey: Keys.segmentStart) as? Date
        lockedDuration = defaults.double(forKey: Keys.lockedDuration)
        lockedNet = defaults.double(forKey: Keys.lockedNet)
        lockedGross = defaults.double(forKey: Keys.lockedGross)
        segmentNetPerSecond = defaults.double(forKey: Keys.segmentNet)
        segmentGrossPerSecond = defaults.double(forKey: Keys.segmentGross)

        // A running session without a segment start is corrupt; keep what was locked in as paused.
        if restored == .running && segmentStartDate == nil {
            state = lockedDuration > 0 ? .paused : .idle
        } else {
            state = restored
        }
    }

    // MARK: Live Activity

    private func liveActivityState(at now: Date) -> SalaryTimerAttributes.ContentState {
        let elapsedNow = elapsed(at: now)
        return SalaryTimerAttributes.ContentState(
            sessionStartDate: now.addingTimeInterval(-elapsedNow),
            amountAnchorDate: now,
            startingAmount: netEarned(at: now),
            earningPerSecond: segmentNetPerSecond,
            pausedAt: state == .paused ? now : nil,
            currencySymbol: defaults.string(forKey: ProfileKeys.currencySymbol) ?? Money.defaultSymbol,
            goalAmount: SessionGoal.current(defaults)
        )
    }

    /// On launch: reattach to the activity of a restored session, or end leftovers.
    private func reconcileLiveActivities() {
        let activities = Activity<SalaryTimerAttributes>.activities
        guard state != .idle else {
            endAllLiveActivities()
            return
        }

        liveActivity = activities.first
        for extra in activities.dropFirst() {
            Task { await extra.end(nil, dismissalPolicy: .immediate) }
        }

        if liveActivity != nil {
            updateLiveActivity(at: .now)
        } else if state == .running {
            startOrUpdateLiveActivity(at: .now)
        }
        if state == .running {
            startRefreshLoop()
        }
    }

    private func startOrUpdateLiveActivity(at now: Date) {
        if liveActivity != nil {
            updateLiveActivity(at: now)
            return
        }
        guard segmentNetPerSecond > 0, ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let content = ActivityContent(state: liveActivityState(at: now), staleDate: nil)
        do {
            liveActivity = try Activity.request(
                attributes: SalaryTimerAttributes(),
                content: content,
                pushType: nil
            )
        } catch {
            liveActivity = nil
        }
    }

    private func updateLiveActivity(at now: Date) {
        guard let liveActivity else { return }
        let content = ActivityContent(state: liveActivityState(at: now), staleDate: nil)
        Task { await liveActivity.update(content) }
    }

    private func endLiveActivity() {
        guard let activity = liveActivity else { return }
        liveActivity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }

    private func endAllLiveActivities() {
        liveActivity = nil
        for activity in Activity<SalaryTimerAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    /// The widget computes the amount at render time, so nudge it periodically while running.
    private func startRefreshLoop() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self, liveActivityRefreshInterval] in
            while !Task.isCancelled {
                try? await Task.sleep(for: liveActivityRefreshInterval)
                guard !Task.isCancelled else { return }
                self?.updateLiveActivity(at: .now)
            }
        }
    }

    private func stopRefreshLoop() {
        refreshTask?.cancel()
        refreshTask = nil
    }
}
