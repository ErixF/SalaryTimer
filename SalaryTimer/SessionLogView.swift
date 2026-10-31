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

    @AppStorage(ProfileKeys.currencySymbol) private var currencySymbol: String = Money.defaultSymbol

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $segment) {
                    Text("All Records").tag(Segment.all)
                    Text("Top 10").tag(Segment.top)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom)

                switch segment {
                case .all:
                    AllRecordsList(currencySymbol: currencySymbol)
                case .top:
                    TopTenList(currencySymbol: currencySymbol)
                }
            }
            .background {
                ScreenBackground()
                    .ignoresSafeArea()
            }
            .navigationTitle(segment == .all ? "All Records" : "Top 10")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            #if DEBUG
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    DebugSampleDataMenu()
                }
            }
            #endif
        }
    }
}

// MARK: - All Records

private struct AllRecordsList: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SalarySession.endDate, order: .reverse) private var sessions: [SalarySession]

    /// Collapsed group ids. Collapsing only hides rows; the section and its header stay,
    /// so the index bar keeps every entry and can still jump to a collapsed group.
    @State private var collapsed: Set<Date> = []

    /// Trailing content margin that keeps rows clear of the section index bar.
    private let indexBarClearance: CGFloat = 30

    let currencySymbol: String

    var body: some View {
        let groups = SessionGrouping.groups(sessions)

        VStack(spacing: 0) {
            // Outside the list, so rows never scroll behind the cards.
            SummaryStrip(sessions: sessions, currencySymbol: currencySymbol)
                .padding(.horizontal, 20)
                .padding(.bottom, 4)

            List {
            ForEach(groups) { group in
                Section {
                    // Always one ForEach (empty when collapsed) so the List structure stays static.
                    ForEach(collapsed.contains(group.id) ? [] : group.sessions) { session in
                        SessionRow(
                            session: session,
                            currencySymbol: currencySymbol,
                            trailingText: group.kind == .day
                                ? SessionFormatters.time(session.endDate)
                                : SessionFormatters.monthDay.string(from: session.endDate)
                        )
                        .listRowBackground(RowBackground())
                    }
                    .onDelete { indices in
                        delete(at: indices, in: group)
                    }
                } header: {
                    groupHeader(group)
                }
                .sectionIndexLabel(group.indexLabel)
            }
        }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .listSectionIndexVisibility(.visible)
            // Extra trailing room so rows don't crowd the section index bar.
            .contentMargins(.trailing, indexBarClearance, for: .scrollContent)
            .topFade()
        }
    }

    private func groupHeader(_ group: SessionDayGroup) -> some View {
        let isCollapsed = collapsed.contains(group.id)
        return HStack(spacing: 8) {
                Text(group.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                Text(SessionFormatters.money(group.total, symbol: currencySymbol))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.blue)

                Image(systemName: "chevron.down")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.orange)
                    .rotationEffect(.degrees(isCollapsed ? -90 : 0))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.25)) {
                if isCollapsed {
                    collapsed.remove(group.id)
                } else {
                    collapsed.insert(group.id)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .textCase(nil)
        .padding(.leading, -8)
        .accessibilityLabel("\(group.title), \(SessionFormatters.money(group.total, symbol: currencySymbol))")
        .accessibilityHint(isCollapsed ? "Expands this group" : "Collapses this group")
    }

    private func delete(at indices: IndexSet, in group: SessionDayGroup) {
        for index in indices {
            modelContext.delete(group.sessions[index])
        }
    }
}

// MARK: - Summary

private struct SummaryStrip: View {
    let sessions: [SalarySession]
    let currencySymbol: String

    var body: some View {
        let total = sessions.reduce(0) { $0 + $1.totalEarned }
        let seconds = sessions.reduce(0) { $0 + $1.duration }

        HStack(spacing: 10) {
            tile("Total earned", SessionFormatters.money(total, symbol: currencySymbol))
            tile("Total time", SessionFormatters.duration(seconds))
            tile("Sessions", "\(sessions.count)")
        }
    }

    private func tile(_ label: String, _ value: String) -> some View {
        GroupedCard {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.top, 3)
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

        List {
            Section {
                ForEach(Array(top.enumerated()), id: \.element.id) { index, session in
                    HStack(alignment: .top, spacing: 12) {
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
            }
    }
}

// MARK: - Shared Row

private struct SessionRow: View {
    let session: SalarySession
    let currencySymbol: String
    let trailingText: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(SessionFormatters.money(session.totalEarned, symbol: currencySymbol))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text("\(SessionFormatters.duration(session.duration)) • \(SessionFormatters.unitPrice(session.unitPrice, symbol: currencySymbol))/sec")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(trailingText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
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
        .padding(.top, 2)
        .accessibilityLabel("Rank \(rank)")
    }
}

// MARK: - Grouping

struct SessionDayGroup: Identifiable {
    enum Kind {
        case day
        case month
    }

    let id: Date
    let kind: Kind
    let title: String
    let indexLabel: String
    let sessions: [SalarySession]

    var total: Double { sessions.reduce(0) { $0 + $1.totalEarned } }
}

private enum SessionGrouping {
    /// Days in the past 30 days get their own group; anything older is grouped by month.
    static func groups(_ sessions: [SalarySession], now: Date = .now) -> [SessionDayGroup] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let dailyCutoff = calendar.date(byAdding: .day, value: -30, to: today) ?? today

        var dayBuckets: [Date: [SalarySession]] = [:]
        var monthBuckets: [Date: [SalarySession]] = [:]
        for session in sessions {
            let day = calendar.startOfDay(for: session.endDate)
            if day >= dailyCutoff {
                dayBuckets[day, default: []].append(session)
            } else {
                let month = calendar.dateInterval(of: .month, for: day)?.start ?? day
                monthBuckets[month, default: []].append(session)
            }
        }

        let days = dayBuckets.keys.sorted(by: >).map { day in
            SessionDayGroup(
                id: day,
                kind: .day,
                title: dayTitle(day, calendar: calendar),
                indexLabel: "\(calendar.component(.day, from: day))",
                sessions: dayBuckets[day, default: []].sorted { $0.endDate > $1.endDate }
            )
        }
        let months = monthBuckets.keys.sorted(by: >).map { month in
            SessionDayGroup(
                id: month,
                kind: .month,
                title: monthTitle(month, now: now, calendar: calendar),
                indexLabel: monthIndexLabel(month, now: now, calendar: calendar),
                sessions: monthBuckets[month, default: []].sorted { $0.endDate > $1.endDate }
            )
        }
        // Month ids can coincide with a day id (the 1st), so they're kept as separate lists.
        return days + months
    }

    private static func dayTitle(_ day: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return SessionFormatters.monthDay.string(from: day)
    }

    private static func monthTitle(_ month: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(month, equalTo: now, toGranularity: .year) {
            return month.formatted(.dateTime.month(.wide))
        }
        return month.formatted(.dateTime.month(.wide).year())
    }

    /// Short month, e.g. "Sep", or "Sep ’25" outside the current year.
    private static func monthIndexLabel(_ month: Date, now: Date, calendar: Calendar) -> String {
        let name = month.formatted(.dateTime.month(.abbreviated))
        if calendar.isDate(month, equalTo: now, toGranularity: .year) {
            return name
        }
        return "\(name) ’\(month.formatted(.dateTime.year(.twoDigits)))"
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
