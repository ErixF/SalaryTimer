//
//  SessionLogView.swift
//  SalaryTimer
//
//  Created by Eric Feng on 6/3/26.
//

import SwiftUI
import SwiftData

struct SessionLogView: View {
    enum Segment: Hashable {
        case all
        case top
    }

    @State private var segment: Segment = .all

    /// Minimum gap between the top screen edge and the pane headers when the nav bar is hidden.
    private let minimumTopClearance: CGFloat = 32

    @AppStorage(ProfileKeys.currencySymbol) private var currencySymbol: String = Money.defaultSymbol

    /// Inside Alternative Look's Home. No `NavigationStack` then: its UIKit container reserves
    /// the side bar's width even though Records sits on the far side, which squeezed the column.
    /// The title is drawn in the content instead.
    var isEmbedded = false

    var body: some View {
        if isEmbedded {
            content
        } else {
            NavigationStack {
                content
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
        }
    }

    private var content: some View {
        GeometryReader { geo in
            if let fold = geo.verticalFold {
                foldedLayout(size: geo.size, fold: fold, topInset: geo.safeAreaInsets.top)
            } else {
                segmentedLayout(topInset: geo.safeAreaInsets.top)
            }
        }
        .background {
            ScreenBackground()
                .ignoresSafeArea()
        }
    }

    private func segmentedLayout(topInset: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if isEmbedded {
                Text(segment == .all ? "All Records" : "Top 10")
                    .font(.largeTitle.bold())
                    .padding(.horizontal, 20)
                    .padding(.top, max(8, minimumTopClearance - topInset))
                    .padding(.bottom, 8)
            }

            Picker("", selection: $segment) {
                Text("All Records").tag(Segment.all)
                Text("Top 10").tag(Segment.top)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom)

            switch segment {
            case .all:
                AllRecordsList(currencySymbol: currencySymbol, stacksSummary: isEmbedded)
            case .top:
                TopTenList(currencySymbol: currencySymbol)
            }
        }
        .navigationTitle(segment == .all ? "All Records" : "Top 10")
        .navigationBarTitleDisplayMode(.large)
    }

    /// Half-open inner display in landscape: All Records on the left half, Top 10 on the right,
    /// the fold clear between them. No segmented control needed.
    private func foldedLayout(size: CGSize, fold: CGRect, topInset: CGFloat) -> some View {
        let clearance: CGFloat = 16
        // The nav bar is hidden here, so give the headers their own room below the top edge.
        let topPadding = max(8, minimumTopClearance - topInset)
        return HStack(spacing: 0) {
            pane("All Records") {
                AllRecordsList(currencySymbol: currencySymbol)
            }
            .frame(width: max(0, fold.minX - clearance))

            Color.clear
                .frame(width: fold.width + clearance * 2)

            pane("Top 10") {
                TopTenList(currencySymbol: currencySymbol)
            }
            .frame(width: max(0, size.width - fold.maxX - clearance))
        }
        .padding(.top, topPadding)
        .navigationTitle("Records")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func pane<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.largeTitle.bold())
                .padding(.horizontal, 20)
                .padding(.top, 8)
            content()
        }
    }
}

// MARK: - All Records

/// Bank-statement style: one month at a time (selector with the month's total), day sections
/// with their totals, and the section index listing that month's day numbers.
private struct AllRecordsList: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SalarySession.endDate, order: .reverse) private var sessions: [SalarySession]

    /// `nil` = the newest month with records.
    @State private var selectedMonthID: Date?

    let currencySymbol: String
    var stacksSummary = false

    var body: some View {
        let months = SessionGrouping.months(sessions)

        if let month = months.first(where: { $0.id == selectedMonthID }) ?? months.first {
            VStack(spacing: 0) {
                // Outside the list, so rows never scroll behind the cards. All-time totals.
                SummaryStrip(sessions: sessions, currencySymbol: currencySymbol, isStacked: stacksSummary)
                    .padding(.horizontal, 20)

                MonthSelector(
                    months: months,
                    selected: month,
                    currencySymbol: currencySymbol,
                    onSelect: { id in
                        withAnimation(.easeInOut(duration: 0.2)) { selectedMonthID = id }
                    }
                )
                .padding(.top, 14)

                List {
                    ForEach(month.days) { day in
                        Section {
                            ForEach(day.sessions) { session in
                                SessionRow(
                                    session: session,
                                    currencySymbol: currencySymbol,
                                    trailingText: SessionFormatters.time(session.endDate)
                                )
                                .listRowBackground(RowBackground())
                            }
                            .onDelete { indices in
                                delete(at: indices, in: day)
                            }
                        } header: {
                            dayHeader(day)
                        }
                        .sectionIndexLabel(day.indexLabel)
                    }
                }
                // A fresh list per month, so scroll position and index start at the top.
                .id(month.id)
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .listSectionIndexVisibility(.visible)
                .topFade()
            }
            .onChange(of: months.map(\.id)) { _, ids in
                // The selected month lost its last record: fall back to the newest month.
                if let selectedMonthID, !ids.contains(selectedMonthID) {
                    self.selectedMonthID = nil
                }
            }
        } else {
            ContentUnavailableView(
                "No records yet",
                systemImage: "tray",
                description: Text("Pause the meter and tap Archive & Reset to save a session here.")
            )
        }
    }

    private func dayHeader(_ day: SessionDayGroup) -> some View {
        HStack(spacing: 8) {
            Text(day.title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            Text(SessionFormatters.money(day.total, symbol: currencySymbol))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.blue)
        }
        .textCase(nil)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func delete(at indices: IndexSet, in day: SessionDayGroup) {
        for index in indices {
            modelContext.delete(day.sessions[index])
        }
    }
}

// MARK: - Month selector

/// ‹  November ▾  ›, with the month's total under it. The arrows step between months that have
/// records (left = older); the menu lists every such month with its total.
private struct MonthSelector: View {
    let months: [SessionMonthGroup]
    let selected: SessionMonthGroup
    let currencySymbol: String
    let onSelect: (Date?) -> Void

    private var index: Int { months.firstIndex { $0.id == selected.id } ?? 0 }
    private var older: SessionMonthGroup? { index + 1 < months.count ? months[index + 1] : nil }
    private var newer: SessionMonthGroup? { index > 0 ? months[index - 1] : nil }

    var body: some View {
        HStack(spacing: 0) {
            stepButton("chevron.left", label: "Previous month", target: older)

            Spacer(minLength: 8)

            VStack(spacing: 2) {
                Menu {
                    ForEach(months) { month in
                        Button("\(month.title) — \(money(month.total))") { onSelect(month.id) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selected.title)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
                // Menus tint their label with the accent color; the month reads as a title, not a link.
                .tint(.primary)
                .accessibilityLabel("Month, \(selected.title)")

                Text("\(money(selected.total)) · \(ValueLabels.sessions(selected.sessions.count))")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.blue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 8)

            stepButton("chevron.right", label: "Next month", target: newer)
        }
        // The chevron glyphs sit on the 20pt content edge.
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    private func stepButton(_ symbol: String, label: String, target: SessionMonthGroup?) -> some View {
        Button {
            if let target { onSelect(target.id) }
        } label: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(target == nil ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.secondary))
        .disabled(target == nil)
        .accessibilityLabel(label)
    }

    private func money(_ value: Double) -> String {
        SessionFormatters.money(value, symbol: currencySymbol)
    }
}

// MARK: - Summary

private struct SummaryStrip: View {
    let sessions: [SalarySession]
    let currencySymbol: String
    /// Two rows (earned + time, then sessions) for narrow columns like the Home's Records third.
    var isStacked = false

    var body: some View {
        let total = sessions.reduce(0) { $0 + $1.totalEarned }
        let seconds = sessions.reduce(0) { $0 + $1.duration }

        if isStacked {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    tile("Total earned", SessionFormatters.money(total, symbol: currencySymbol))
                    tile("Total time", SessionFormatters.duration(seconds))
                }
                .fixedSize(horizontal: false, vertical: true)
                inlineTile("Sessions", "\(sessions.count)")
            }
        } else {
            HStack(spacing: 10) {
                tile("Total earned", SessionFormatters.money(total, symbol: currencySymbol))
                tile("Total time", SessionFormatters.duration(seconds))
                tile("Sessions", "\(sessions.count)")
            }
            // Equal-height cards: each fills the tallest one's height.
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Three across a phone width: tighter padding and tracking so the labels and values fit at
    /// full size (they only shrink on the narrowest widths or very large text).
    private func tile(_ label: String, _ value: String) -> some View {
        GroupedCard(horizontalPadding: 12, fillsHeight: true) {
            Text(label)
                .font(AppFont.label)
                .tracking(0.4)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(AppFont.summaryValue)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 3)
        }
        .accessibilityElement(children: .combine)
    }

    /// One-line tile: label on the left, value on the right (like the Meter's goal card).
    private func inlineTile(_ label: String, _ value: String) -> some View {
        GroupedCard {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(AppFont.label)
                    .tracking(AppFont.labelTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(value)
                    .font(AppFont.summaryValue)
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Top 10

private struct TopTenList: View {
    @Query(sort: \SalarySession.totalEarned, order: .reverse) private var sessions: [SalarySession]

    let currencySymbol: String

    var body: some View {
        let top = Array(sessions.prefix(10))

        if top.isEmpty {
            ContentUnavailableView("No records yet", systemImage: "trophy")
        } else {
            list(top)
        }
    }

    private func list(_ top: [SalarySession]) -> some View {
        List {
            Section {
                ForEach(Array(top.enumerated()), id: \.element.id) { index, session in
                    // Medal / number sits on the amount line, not between the two lines.
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        RankBadge(rank: index + 1)
                        SessionRow(
                            session: session,
                            currencySymbol: currencySymbol,
                            trailingText: SessionFormatters.dayOrTime(session.endDate)
                        )
                    }
                    .listRowBackground(RowBackground())
                }
            } footer: {
                Text("Top 10 by earnings, across all sessions.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .topFade()
    }
}

// MARK: - Top fade

private extension View {
    /// Rows fade out in a band at the top of the list, so they disappear before reaching
    /// whatever sits above it (summary cards or the segmented control). Content starts below
    /// the band, so nothing looks faded at rest.
    func topFade(height: CGFloat = 24) -> some View {
        contentMargins(.top, height, for: .scrollContent)
            .mask {
                VStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: height)
                    Color.black
                }
                // Extend past the bottom edge so rows keep scrolling under the tab bar.
                .padding(.bottom, -200)
            }
    }
}

// MARK: - Shared Row

private struct SessionRow: View {
    let session: SalarySession
    let currencySymbol: String
    let trailingText: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(SessionFormatters.money(session.totalEarned, symbol: currencySymbol))
                    .font(AppFont.value)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text("\(SessionFormatters.duration(session.duration)) · \(SessionFormatters.unitPrice(session.unitPrice, symbol: currencySymbol))/sec")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(trailingText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Rank Badge

/// Gold / silver / bronze `medal.fill` for 1–3, plain numbers for 4–10.
private struct RankBadge: View {
    let rank: Int

    private var medalColor: Color? {
        switch rank {
        case 1: Color(red: 0.95, green: 0.73, blue: 0.13)
        case 2: Color(red: 0.73, green: 0.76, blue: 0.80)
        case 3: Color(red: 0.79, green: 0.48, blue: 0.24)
        default: nil
        }
    }

    var body: some View {
        Group {
            if let medalColor {
                Image(systemName: "medal.fill")
                    .font(.title2)
                    .foregroundStyle(medalColor)
            } else {
                Text("\(rank)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 28, alignment: .center)
        .accessibilityLabel("Rank \(rank)")
    }
}

// MARK: - Grouping

struct SessionDayGroup: Identifiable {
    /// Start of the day.
    let id: Date
    /// Today / Yesterday / "Mon, Nov 3".
    let title: String
    /// Day of the month, for the section index.
    let indexLabel: String
    let sessions: [SalarySession]

    var total: Double { sessions.reduce(0) { $0 + $1.totalEarned } }
}

struct SessionMonthGroup: Identifiable {
    /// Start of the month.
    let id: Date
    /// "November", or "November 2025" outside the current year.
    let title: String
    let days: [SessionDayGroup]

    var sessions: [SalarySession] { days.flatMap(\.sessions) }
    var total: Double { days.reduce(0) { $0 + $1.total } }
}

private enum SessionGrouping {
    /// Months newest first; each month's days newest first; each day's sessions newest first.
    static func months(_ sessions: [SalarySession], now: Date = .now) -> [SessionMonthGroup] {
        let calendar = Calendar.current

        var dayBuckets: [Date: [SalarySession]] = [:]
        for session in sessions {
            dayBuckets[calendar.startOfDay(for: session.endDate), default: []].append(session)
        }

        var monthBuckets: [Date: [SessionDayGroup]] = [:]
        for day in dayBuckets.keys.sorted(by: >) {
            let month = calendar.dateInterval(of: .month, for: day)?.start ?? day
            monthBuckets[month, default: []].append(
                SessionDayGroup(
                    id: day,
                    title: dayTitle(day, calendar: calendar),
                    indexLabel: "\(calendar.component(.day, from: day))",
                    sessions: dayBuckets[day, default: []].sorted { $0.endDate > $1.endDate }
                )
            )
        }

        return monthBuckets.keys.sorted(by: >).map { month in
            SessionMonthGroup(
                id: month,
                title: monthTitle(month, now: now, calendar: calendar),
                days: monthBuckets[month, default: []]
            )
        }
    }

    private static func dayTitle(_ day: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private static func monthTitle(_ month: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(month, equalTo: now, toGranularity: .year) {
            return month.formatted(.dateTime.month(.wide))
        }
        return month.formatted(.dateTime.month(.wide).year())
    }
}

// MARK: - Formatters

enum SessionFormatters {
    static let monthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter
    }()

    /// `1h 42min`, `3min 6s`, or `45s`.
    static func duration(_ duration: TimeInterval) -> String {
        let total = max(0, Int(duration.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if hours > 0 {
            return "\(hours)h \(minutes)min"
        }
        if minutes > 0 {
            return "\(minutes)min \(seconds)s"
        }
        return "\(seconds)s"
    }

    static func unitPrice(_ value: Double, symbol: String) -> String {
        Money.string(value, symbol: symbol, fractionDigits: 4...4)
    }

    /// `$1,234.56` with the user's symbol, rather than the locale's "US$".
    static func money(_ value: Double, symbol: String) -> String {
        Money.string(value, symbol: symbol)
    }

    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// Time for today's records, otherwise `Oct 18`.
    static func dayOrTime(_ date: Date) -> String {
        Calendar.current.isDateInToday(date) ? time(date) : monthDay.string(from: date)
    }
}

// Empty on purpose: Xcode Previews (iOS 27.1) crash in PreviewsInjection when a List has rows.
// Runs fine in the real app; check populated Records on a simulator or device.
#Preview {
    SessionLogView()
        .environment(SalaryTimerStore(restoresSession: false))
        .modelContainer(for: SalarySession.self, inMemory: true)
}
