//
//  SalaryTimerLiveActivity.swift
//  SalaryTimer
//
//  Created by Eric Feng on 5/22/25.
//

import WidgetKit
import SwiftUI
import ActivityKit

struct SalaryTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SalaryTimerAttributes.self) { context in
            SalaryTimerExpandedView(context: context)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    SalaryTimerTickerLabel(context: context, font: .headline)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    SalaryTimerRateLabel(context: context)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    SalaryTimerExpandedFooter(context: context)
                }
            } compactLeading: {
                SalaryTimerCompactView(context: context)
            } compactTrailing: {
                SalaryTimerCompactRateView(context: context)
            } minimal: {
                SalaryTimerMinimalView(context: context)
            }
            .widgetURL(URL(string: "salarytimer://live"))
            .keylineTint(Color.green)
        }
    }
}

private struct SalaryTimerExpandedView: View {
    let context: ActivityViewContext<SalaryTimerAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Income")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))

                    SalaryTimerTickerLabel(context: context, font: .system(size: 30, weight: .bold, design: .rounded))
                }

                Spacer(minLength: 12)

                SalaryTimerRateLabel(context: context)
            }

            SalaryTimerExpandedFooter(context: context)
        }
        .foregroundStyle(.white)
    }
}

private struct SalaryTimerExpandedFooter: View {
    let context: ActivityViewContext<SalaryTimerAttributes>

    var body: some View {
        HStack {
            Text(timerInterval: context.state.startDate ... .distantFuture, countsDown: false, showsHours: true)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.white.opacity(0.86))

            Spacer(minLength: 12)

            Text("LIVE")
                .font(.caption2.weight(.bold))
                .tracking(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.22), in: Capsule())
                .foregroundStyle(.green)
        }
    }
}

private struct SalaryTimerCompactView: View {
    let context: ActivityViewContext<SalaryTimerAttributes>

    var body: some View {
        SalaryTimerTickerLabel(context: context, font: .system(size: 13, weight: .semibold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SalaryTimerCompactRateView: View {
    let context: ActivityViewContext<SalaryTimerAttributes>

    var body: some View {
        Text(context.state.earningPerSecond, format: .currency(code: context.attributes.currencyCode))
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

private struct SalaryTimerMinimalView: View {
    let context: ActivityViewContext<SalaryTimerAttributes>

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.green.opacity(0.18))

            Text(minimalText)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.55)
                .padding(4)
        }
    }

    private var minimalText: String {
        let amount = SalaryTimerAmountCalculator.amount(for: context.state, now: Date())
        return amount < 100 ? amount.formatted(.number.precision(.fractionLength(0...1))) : amount.formatted(.number.precision(.fractionLength(0)))
    }
}

private struct SalaryTimerTickerLabel: View {
    let context: ActivityViewContext<SalaryTimerAttributes>
    let font: Font

    private var amount: Double {
        SalaryTimerAmountCalculator.amount(for: context.state, now: Date())
    }

    var body: some View {
        Text(amount, format: .currency(code: context.attributes.currencyCode))
            .font(font)
            .monospacedDigit()
            .contentTransition(.numericText(value: amount))
    }
}

private struct SalaryTimerRateLabel: View {
    let context: ActivityViewContext<SalaryTimerAttributes>

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("Rate")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))

            Text("\(context.state.earningPerSecond.formatted(.number.precision(.fractionLength(4))))/s")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.green)
        }
    }
}

private enum SalaryTimerAmountCalculator {
    static func amount(for state: SalaryTimerAttributes.ContentState, now: Date) -> Double {
        let elapsed = max(0, now.timeIntervalSince(state.startDate))
        return state.startingAmount + (elapsed * state.earningPerSecond)
    }
}

extension SalaryTimerAttributes {
    fileprivate static var preview: SalaryTimerAttributes {
        SalaryTimerAttributes()
    }
}

#Preview("Notification", as: .content, using: SalaryTimerAttributes.preview) {
    SalaryTimerLiveActivity()
} contentStates: {
    SalaryTimerAttributes.ContentState(
        startDate: Date().addingTimeInterval(-420),
        startingAmount: 123.45,
        earningPerSecond: 0.0184
    )
}
