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
// parts here are the elapsed timer and a timer-driven progress bar. Everything else is drawn
// from the last state the app pushed.

struct SalaryTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SalaryTimerAttributes.self) { context in
            MeterActivityView(state: context.state, onDarkBackground: false)
                .padding(14)
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
                RateCapsule(state: context.state)
            } minimal: {
                SymbolBadge(state: context.state)
            }
            .contentMargins(.horizontal, 14, for: .expanded)
            .widgetURL(URL(string: "salarytimer://live"))
            .keylineTint(context.state.tint)
        }
    }
}

// MARK: - State styling

private extension SalaryTimerAttributes.ContentState {
    /// Running green, paused amber — same as the Meter's state chip.
    var tint: Color { isPaused ? .orange : .green }

    var stateTitle: String { isPaused ? "Paused" : "Running" }

    var hourlyRate: Double { earningPerSecond * 3600 }
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
                Text("≈ \(Money.string(state.hourlyRate, symbol: state.currencySymbol))/hr · \(Money.string(state.earningPerSecond, symbol: state.currencySymbol, fractionDigits: 4...4))/sec")
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            LiveTimerText(state: state)
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundStyle(onDarkBackground ? .white : .primary)

            EarningsProgress(state: state, secondary: secondary)
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

// MARK: - Progress toward the next amount

/// A bar that fills live toward the next whole amount, using a timer-driven ProgressView so it
/// moves without app updates. Labels show the whole amounts at each end.
private struct EarningsProgress: View {
    let state: SalaryTimerAttributes.ContentState
    let secondary: Color

    /// Steps so one bar takes at least a minute to fill, even at high rates.
    private static let steps: [Double] = [1, 5, 10, 50, 100, 500, 1000]
    private static let minimumFillTime: TimeInterval = 60

    private var step: Double {
        guard state.earningPerSecond > 0 else { return 1 }
        return Self.steps.first { $0 / state.earningPerSecond >= Self.minimumFillTime } ?? Self.steps.last ?? 1
    }

    /// Amount at the moment the app last updated (or paused).
    private var anchorAmount: Double { state.amount(at: state.pausedAt ?? state.amountAnchorDate) }

    private var lowerBound: Double { (anchorAmount / step).rounded(.down) * step }
    private var upperBound: Double { lowerBound + step }

    /// When the total reaches `amount`, extrapolated from the last update.
    private func date(reaching amount: Double) -> Date {
        state.amountAnchorDate.addingTimeInterval((amount - state.startingAmount) / state.earningPerSecond)
    }

    var body: some View {
        VStack(spacing: 4) {
            Group {
                if state.isPaused || state.earningPerSecond <= 0 {
                    ProgressView(value: (anchorAmount - lowerBound) / step)
                } else {
                    ProgressView(
                        timerInterval: date(reaching: lowerBound) ... date(reaching: upperBound),
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
                Text(Money.string(lowerBound, symbol: state.currencySymbol, fractionDigits: 0...0))
                Spacer()
                Text(Money.string(upperBound, symbol: state.currencySymbol, fractionDigits: 0...0))
            }
            .font(.caption2.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(secondary)
        }
    }
}

// MARK: - Compact & minimal

/// Current hourly rate in a state-colored capsule, snug against the camera.
/// Whole units only (`$50/hr`) so it fits the compact slot, per HIG's "shortened units".
private struct RateCapsule: View {
    let state: SalaryTimerAttributes.ContentState

    var body: some View {
        Text("\(Money.string(state.hourlyRate.rounded(), symbol: state.currencySymbol, fractionDigits: 0...0))/hr")
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(state.tint, in: Capsule())
    }
}

/// The currency symbol in a state-colored circle.
private struct SymbolBadge: View {
    let state: SalaryTimerAttributes.ContentState

    var body: some View {
        Text(state.currencySymbol)
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(state.tint, in: Circle())
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
            earningPerSecond: 0.0139
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
    SalaryTimerAttributes.ContentState.previewPaused
}

#Preview("Compact", as: .dynamicIsland(.compact), using: SalaryTimerAttributes.preview) {
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
