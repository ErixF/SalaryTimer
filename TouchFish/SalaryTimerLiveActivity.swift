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

struct SalaryTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SalaryTimerAttributes.self) { context in
            SalaryTimerExpandedView(context: context, style: .content)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .activityBackgroundTint(nil)
                .activitySystemActionForegroundColor(nil)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    SalaryTimerExpandedView(
                        context: context,
                        amountFont: .system(size: 28, weight: .bold, design: .rounded),
                        style: .dynamicIsland
                    )
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                }
            } compactLeading: {
                SalaryTimerCompactView(context: context)
            } compactTrailing: {
                SalaryTimerCompactRateView(context: context)
            } minimal: {
                SalaryTimerMinimalView(context: context)
            }
            .contentMargins(.all, 16, for: .expanded)
            .widgetURL(URL(string: "salarytimer://live"))
            .keylineTint(Color.green)
        }
    }
}

private struct SalaryTimerExpandedView: View {
    let context: ActivityViewContext<SalaryTimerAttributes>
    let amountFont: Font
    let style: SalaryTimerLiveActivityStyle

    init(
        context: ActivityViewContext<SalaryTimerAttributes>,
        amountFont: Font = .system(size: 30, weight: .bold, design: .rounded),
        style: SalaryTimerLiveActivityStyle = .content
    ) {
        self.context = context
        self.amountFont = amountFont
        self.style = style
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Income")
                        .font(.caption)
                        .foregroundStyle(style.secondaryText)

                    SalaryTimerTickerLabel(context: context, font: amountFont, color: style.primaryText)
                }

                Spacer(minLength: 12)

                SalaryTimerRateLabel(context: context, style: style)
            }

            SalaryTimerExpandedFooter(context: context, style: style)
        }
        .foregroundStyle(style.primaryText)
    }
}

private struct SalaryTimerExpandedFooter: View {
    let context: ActivityViewContext<SalaryTimerAttributes>
    let style: SalaryTimerLiveActivityStyle

    var body: some View {
        HStack {
            Text(timerInterval: context.state.sessionStartDate ... .distantFuture, countsDown: false, showsHours: true)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(style.secondaryText)

            Spacer(minLength: 12)

            Text("LIVE")
                .font(.caption2.weight(.bold))
                .tracking(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(style.badgeBackground, in: Capsule())
                .foregroundStyle(style.accent)
        }
    }
}

private struct SalaryTimerCompactView: View {
    let context: ActivityViewContext<SalaryTimerAttributes>

    var body: some View {
        SalaryTimerTickerLabel(
            context: context,
            font: .system(size: 13, weight: .semibold, design: .rounded),
            color: .white
        )
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

        if amount < 100 {
            return amount.formatted(.number.precision(.fractionLength(0...1)))
        }

        return amount.formatted(.number.precision(.fractionLength(0)))
    }
}

private struct SalaryTimerTickerLabel: View {
    let context: ActivityViewContext<SalaryTimerAttributes>
    let font: Font
    let color: Color

    private var amount: Double {
        SalaryTimerAmountCalculator.amount(for: context.state, now: Date())
    }

    var body: some View {
        Text(amount, format: .currency(code: context.attributes.currencyCode))
            .font(font)
            .monospacedDigit()
            .foregroundStyle(color)
            .contentTransition(.numericText(value: amount))
    }
}

private struct SalaryTimerRateLabel: View {
    let context: ActivityViewContext<SalaryTimerAttributes>
    let style: SalaryTimerLiveActivityStyle

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("Rate")
                .font(.caption)
                .foregroundStyle(style.secondaryText)

            Text("\(context.state.earningPerSecond.formatted(.number.precision(.fractionLength(4))))/s")
                .font(.headline.monospacedDigit())
                .foregroundStyle(style.accent)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

private enum SalaryTimerLiveActivityStyle {
    case content
    case dynamicIsland

    var primaryText: Color {
        switch self {
        case .content:
            return .primary
        case .dynamicIsland:
            return .white
        }
    }

    var secondaryText: Color {
        switch self {
        case .content:
            return .secondary
        case .dynamicIsland:
            return .white.opacity(0.78)
        }
    }

    var accent: Color {
        switch self {
        case .content:
            return .green
        case .dynamicIsland:
            return .green
        }
    }

    var badgeBackground: Color {
        switch self {
        case .content:
            return .green.opacity(0.14)
        case .dynamicIsland:
            return .green.opacity(0.22)
        }
    }
}

private enum SalaryTimerAmountCalculator {
    static func amount(for state: SalaryTimerAttributes.ContentState, now: Date) -> Double {
        let elapsed = max(0, now.timeIntervalSince(state.amountAnchorDate))
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
        sessionStartDate: Date().addingTimeInterval(-420),
        amountAnchorDate: Date().addingTimeInterval(-30),
        startingAmount: 123.45,
        earningPerSecond: 0.0184
    )
}
