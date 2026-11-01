//
//  SalaryTimerLiveActivity.swift
//  SalaryTimer
//
//  Created by Eric Feng on 5/22/25.
//

import WidgetKit
import SwiftUI
import ActivityKit
import Foundation

// Live Activities can only animate Apple's built-in timer views on their own, so the moving
// parts here are the elapsed timer and a timer-driven session-goal bar. Everything else is drawn
// from the last state the app pushed.

struct SalaryTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SalaryTimerAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(nil)
                .activitySystemActionForegroundColor(nil)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    MeterActivityView(state: context.state, onDarkBackground: true)
                        .padding(.horizontal, 6)
                        .padding(.bottom, 4)
                }
            } compactLeading: {
                LiveTimerText(state: context.state)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: 56, alignment: .leading)
            } compactTrailing: {
                GoalRing(state: context.state, lineWidth: 3, symbolSize: 10)
                    .frame(width: 24, height: 24)
            } minimal: {
                GoalRing(state: context.state, lineWidth: 3, symbolSize: 11)
            }
            .contentMargins(.horizontal, 14, for: .expanded)
            .widgetURL(URL(string: "salarytimer://live"))
            .keylineTint(context.state.tint)
        }
        // A custom layout for the Apple Watch Smart Stack and CarPlay.
        .supplementalActivityFamilies([.small])
    }
}

/// Lock Screen view, or the compact Watch / CarPlay layout for the `.small` family.
private struct LockScreenView: View {
    let state: SalaryTimerAttributes.ContentState
    @Environment(\.activityFamily) private var activityFamily

    var body: some View {
        if activityFamily == .small {
            SmallMeterView(state: state)
        } else {
            MeterActivityView(state: state, onDarkBackground: false)
                .padding(14)
        }
    }
}

// MARK: - State styling

private extension SalaryTimerAttributes.ContentState {
    /// Running green, paused amber — same as the Meter's state chip.
    var tint: Color { isPaused ? .orange : .green }

    var stateTitle: String { isPaused ? "Paused" : "Running" }

    var hourlyRate: Double { earningPerSecond * 3600 }

    /// Total as of the last update from the app (frozen while paused).
    var lastKnownAmount: Double { amount(at: pausedAt ?? amountAnchorDate) }

    /// When the total reaches `target`, extrapolated from the last update.
    func date(reaching target: Double) -> Date {
        amountAnchorDate.addingTimeInterval((target - startingAmount) / earningPerSecond)
    }

    /// Whether progress can fill on its own from a timer (running with a rate, goal not yet hit).
    func fillsLive(toward goal: Double) -> Bool {
        !isPaused && earningPerSecond > 0 && lastKnownAmount < goal
    }
}

// MARK: - Lock Screen & expanded

private struct MeterActivityView: View {
    let state: SalaryTimerAttributes.ContentState
    /// The Dynamic Island is always dark; the Lock Screen follows the system appearance.
    let onDarkBackground: Bool

    private var secondary: Color { onDarkBackground ? .white.opacity(0.7) : .secondary }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                StateChip(state: state)
                Spacer(minLength: 8)
                Text("\(Money.string(state.hourlyRate, symbol: state.currencySymbol))/hr ≈ \(Money.string(state.earningPerSecond, symbol: state.currencySymbol, fractionDigits: 4...4))/sec")
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            LiveTimerText(state: state)
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundStyle(onDarkBackground ? .white : .primary)

            if let goal = state.goalAmount, goal > 0 {
                GoalProgress(state: state, goal: goal, secondary: secondary)
            }
        }
    }
}

/// Elapsed time, counting up live; stops at the pause point while paused.
private struct LiveTimerText: View {
    let state: SalaryTimerAttributes.ContentState

    var body: some View {
        Text(
            timerInterval: state.sessionStartDate ... .distantFuture,
            pauseTime: state.pausedAt,
            countsDown: false,
            showsHours: true
        )
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

private struct StateChip: View {
    let state: SalaryTimerAttributes.ContentState

    var body: some View {
        Text(state.stateTitle)
            .font(.caption2.weight(.bold))
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(state.tint, in: Capsule())
    }
}

// MARK: - Session goal progress

/// Fills from $0 to the session goal over the whole session. Timer-driven, so it moves without
/// app updates and never needs to restart; a resume pushes fresh state that re-anchors it.
private struct GoalProgress: View {
    let state: SalaryTimerAttributes.ContentState
    let goal: Double
    let secondary: Color

    /// As of the last update from the app; the bar itself fills on its own regardless.
    private var isReached: Bool { state.lastKnownAmount >= goal }

    var body: some View {
        VStack(spacing: 4) {
            Group {
                if !state.fillsLive(toward: goal) {
                    ProgressView(value: min(1, state.lastKnownAmount / goal))
                } else {
                    ProgressView(
                        timerInterval: state.date(reaching: 0) ... state.date(reaching: goal),
                        countsDown: false
                    ) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                }
            }
            .progressViewStyle(.linear)
            .tint(state.tint)
            .labelsHidden()

            HStack {
                Text(Money.string(0, symbol: state.currencySymbol, fractionDigits: 0...0))
                Spacer()
                HStack(spacing: 4) {
                    Text("Goal \(Money.string(goal, symbol: state.currencySymbol, fractionDigits: 0...2))")
                    if isReached {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                            .accessibilityLabel("Goal reached")
                    }
                }
            }
            .font(.caption2.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(secondary)
        }
    }
}

// MARK: - Goal ring (compact, minimal, Watch)

/// State-colored ring that fills from $0 to the session goal, with the currency symbol inside.
/// Timer-driven like the goal bar, so it fills without app updates. With no goal it's a full ring,
/// so the state color still reads at a glance.
private struct GoalRing: View {
    let state: SalaryTimerAttributes.ContentState
    let lineWidth: CGFloat
    let symbolSize: CGFloat

    var body: some View {
        ZStack {
            // The circular style draws its own faint track behind the fill.
            progress
                .progressViewStyle(.circular)
                .tint(state.tint)
                .labelsHidden()

            Text(state.currencySymbol)
                .font(.system(size: symbolSize, weight: .heavy, design: .rounded))
                .foregroundStyle(state.tint)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(lineWidth + 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private var progress: some View {
        if let goal = state.goalAmount, goal > 0 {
            if state.fillsLive(toward: goal) {
                ProgressView(
                    timerInterval: state.date(reaching: 0) ... state.date(reaching: goal),
                    countsDown: false
                ) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
            } else {
                ProgressView(value: min(1, state.lastKnownAmount / goal))
            }
        } else {
            ProgressView(value: 1)
        }
    }

    private var accessibilityText: String {
        guard let goal = state.goalAmount, goal > 0 else { return state.stateTitle }
        return "\(state.stateTitle), goal \(Money.string(goal, symbol: state.currencySymbol, fractionDigits: 0...2))"
    }
}

// MARK: - Apple Watch & CarPlay

/// The `.small` family: goal ring on the left, state, live timer and rate beside it.
/// No buttons (CarPlay disables them, and this is a glance).
private struct SmallMeterView: View {
    let state: SalaryTimerAttributes.ContentState

    var body: some View {
        HStack(spacing: 10) {
            GoalRing(state: state, lineWidth: 5, symbolSize: 18)
                .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 2) {
                Text(state.stateTitle)
                    .font(.caption2.weight(.bold))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(state.tint)

                LiveTimerText(state: state)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)

                Text("\(Money.string(state.hourlyRate.rounded(), symbol: state.currencySymbol, fractionDigits: 0...0))/hr")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
    }
}

// MARK: - Previews

extension SalaryTimerAttributes {
    fileprivate static var preview: SalaryTimerAttributes {
        SalaryTimerAttributes()
    }
}

extension SalaryTimerAttributes.ContentState {
    fileprivate static var previewRunning: Self {
        Self(
            sessionStartDate: .now.addingTimeInterval(-888),
            amountAnchorDate: .now.addingTimeInterval(-30),
            startingAmount: 12.35,
            earningPerSecond: 0.0139,
            goalAmount: 400
        )
    }

    fileprivate static var previewReached: Self {
        Self(
            sessionStartDate: .now.addingTimeInterval(-3600),
            amountAnchorDate: .now,
            startingAmount: 50.04,
            earningPerSecond: 0.0139,
            goalAmount: 50
        )
    }

    fileprivate static var previewPaused: Self {
        Self(
            sessionStartDate: .now.addingTimeInterval(-890),
            amountAnchorDate: .now,
            startingAmount: 12.38,
            earningPerSecond: 0.0139,
            pausedAt: .now
        )
    }
}

#Preview("Lock Screen", as: .content, using: SalaryTimerAttributes.preview) {
    SalaryTimerLiveActivity()
} contentStates: {
    SalaryTimerAttributes.ContentState.previewRunning
    SalaryTimerAttributes.ContentState.previewReached
    SalaryTimerAttributes.ContentState.previewPaused
}

#Preview("Compact", as: .dynamicIsland(.compact), using: SalaryTimerAttributes.preview) {
    SalaryTimerLiveActivity()
} contentStates: {
    SalaryTimerAttributes.ContentState.previewRunning
    SalaryTimerAttributes.ContentState.previewPaused
}

#Preview("Minimal", as: .dynamicIsland(.minimal), using: SalaryTimerAttributes.preview) {
    SalaryTimerLiveActivity()
} contentStates: {
    SalaryTimerAttributes.ContentState.previewRunning
    SalaryTimerAttributes.ContentState.previewPaused
}

#Preview("Expanded", as: .dynamicIsland(.expanded), using: SalaryTimerAttributes.preview) {
    SalaryTimerLiveActivity()
} contentStates: {
    SalaryTimerAttributes.ContentState.previewRunning
}
