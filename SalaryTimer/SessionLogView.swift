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
    @Environment(SalaryTimerStore.self) private var timerStore

    private let currencyCode = "USD"

    var body: some View {
        NavigationStack {
            ZStack {
                RecordsBackground(isRunning: timerStore.isRunning)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Picker("", selection: $segment) {
                        Text("All Records").tag(Segment.all)
                        Text("Top 10").tag(Segment.top)
                    }
                    .pickerStyle(.segmented)
                    .colorScheme(.dark)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 8)

                    switch segment {
                    case .all:
                        AllRecordsList(currencyCode: currencyCode)
                    case .top:
                        TopTenList(currencyCode: currencyCode)
                    }
                }
            }
            .navigationTitle(segment == .all ? "All Records" : "Top 10")
            .navigationBarTitleDisplayMode(.large)
        }
        .colorScheme(.dark)
    }
}

// MARK: - All Records

private struct AllRecordsList: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SalarySession.endDate, order: .reverse) private var sessions: [SalarySession]

    let currencyCode: String

    var body: some View {
        let groups = SessionGrouping.byDay(sessions)

        List {
            ForEach(groups) { group in
                Section {
                    ForEach(group.sessions) { session in
                        SessionRow(session: session, currencyCode: currencyCode)
                            .listRowBackground(listRowBackground)
                    }
                    .onDelete { indices in
                        delete(at: indices, in: group)
                    }
                } header: {
                    Text(group.title)
                        .font(.title3.weight(.bold))
                        .textCase(nil)
                        .padding(.leading, -8)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func delete(at indices: IndexSet, in group: SessionDayGroup) {
        for index in indices {
            modelContext.delete(group.sessions[index])
        }
    }
    
    @ViewBuilder
    private var listRowBackground: some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(.regular.tint(.white.opacity(0.08)).interactive(), in: .rect(cornerRadius: 10))
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
                }
        }
    }
}

// MARK: - Top 10

private struct TopTenList: View {
    @Query(sort: \SalarySession.totalEarned, order: .reverse) private var sessions: [SalarySession]

    let currencyCode: String

    var body: some View {
        let top = Array(sessions.prefix(10))

        List {
            Section {
                ForEach(Array(top.enumerated()), id: \.element.id) { index, session in
                    HStack(spacing: 12) {
                        RankBadge(rank: index + 1)
                        SessionRow(session: session, currencyCode: currencyCode)
                    }
                    .listRowBackground(listRowBackground)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
    
    @ViewBuilder
    private var listRowBackground: some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(.regular.tint(.white.opacity(0.08)).interactive(), in: .rect(cornerRadius: 10))
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
                }
        }
    }
}

// MARK: - Shared Row

private struct SessionRow: View {
    let session: SalarySession
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.totalEarned, format: .currency(code: currencyCode))
                .font(.system(size: 28, weight: .bold, design: .default))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            HStack(spacing: 6) {
                Text(SessionFormatters.duration(session.duration))
                Text("@")
                Text(SessionFormatters.unitPrice(session.unitPrice, currencyCode: currencyCode))
            }
            .font(.subheadline)
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Rank Badge

private struct RankBadge: View {
    let rank: Int

    var body: some View {
        Group {
            switch rank {
            case 1:
                Image(systemName: "medal.fill")
                    .foregroundStyle(Color(red: 0.95, green: 0.78, blue: 0.20))
            case 2:
                Image(systemName: "medal.fill")
                    .foregroundStyle(Color(red: 0.75, green: 0.75, blue: 0.78))
            case 3:
                Image(systemName: "medal.fill")
                    .foregroundStyle(Color(red: 0.80, green: 0.50, blue: 0.20))
            default:
                Text("\(rank)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .font(.title2)
        .frame(width: 32, alignment: .center)
    }
}

// MARK: - Grouping

struct SessionDayGroup: Identifiable {
    let id: Date
    let title: String
    let sessions: [SalarySession]
}

private enum SessionGrouping {
    static func byDay(_ sessions: [SalarySession]) -> [SessionDayGroup] {
        let calendar = Calendar.current
        let buckets = Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.endDate)
        }

        return buckets
            .sorted { $0.key > $1.key }
            .map { (day, sessions) in
                SessionDayGroup(
                    id: day,
                    title: title(for: day, calendar: calendar),
                    sessions: sessions.sorted { $0.endDate > $1.endDate }
                )
            }
    }

    private static func title(for day: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(day) {
            return "Today"
        }
        if calendar.isDateInYesterday(day) {
            return "Yesterday"
        }
        return SessionFormatters.monthDay.string(from: day)
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

    static func duration(_ duration: TimeInterval) -> String {
        let total = max(0, Int(duration))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if hours > 0 {
            return "\(hours)hr \(minutes)min \(seconds)s"
        }
        return "\(minutes)min \(seconds)s"
    }

    static func unitPrice(_ value: Double, currencyCode: String) -> String {
        value.formatted(.currency(code: currencyCode).precision(.fractionLength(3)))
    }
}

#Preview {
    SessionLogView()
        .environment(SalaryTimerStore())
        .modelContainer(for: SalarySession.self, inMemory: true)
}
