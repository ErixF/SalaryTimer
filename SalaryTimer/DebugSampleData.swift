//
//  DebugSampleData.swift
//  SalaryTimer
//
//  Created by Eric Feng on 10/30/26.
//

#if DEBUG
import SwiftUI
import SwiftData

/// Debug-only sample records for checking Records grouping, totals, and the section index.
/// Sample ids are remembered so they can be removed without touching real sessions.
enum DebugSampleData {
    private static let idsKey = "debug.sampleRecordIDs"

    /// Inserts sessions spread over the last ~5 months: 0–3 per day for the past 30 days
    /// (some days empty, so index gaps show), plus scattered older ones for month groups.
    static func insert(into context: ModelContext, now: Date = .now) {
        let calendar = Calendar.current
        var ids = storedIDs()

        func add(daysAgo: Int) {
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: now) else { return }
            let duration = TimeInterval(Int.random(in: 120...(8 * 3600)))
            let grossRates: [Double] = [0.0069, 0.0083, 0.0104, 0.0139]
            let deductions: [Double] = [0, 0, 0.15, 0.25]
            let gross = grossRates.randomElement() ?? 0.0104
            let deduction = deductions.randomElement() ?? 0
            let net = gross * (1 - deduction)
            // End somewhere between 9 AM and 9 PM, never in the future.
            let end = min(now, calendar.startOfDay(for: day).addingTimeInterval(TimeInterval(Int.random(in: 9 * 3600...21 * 3600))))
            let session = SalarySession(
                endDate: end,
                totalEarned: net * duration,
                duration: duration,
                unitPrice: net,
                startDate: end.addingTimeInterval(-duration),
                grossEarned: gross * duration
            )
            context.insert(session)
            ids.append(session.id.uuidString)
        }

        for daysAgo in 0..<30 where Int.random(in: 0..<4) != 0 {
            for _ in 0..<Int.random(in: 1...3) {
                add(daysAgo: daysAgo)
            }
        }
        for _ in 0..<25 {
            add(daysAgo: Int.random(in: 31...150))
        }

        UserDefaults.standard.set(ids, forKey: idsKey)
    }

    /// Deletes only the sessions created by `insert`.
    static func remove(from context: ModelContext) {
        let ids = Set(storedIDs().compactMap(UUID.init(uuidString:)))
        guard !ids.isEmpty else { return }
        let sessions = (try? context.fetch(FetchDescriptor<SalarySession>())) ?? []
        for session in sessions where ids.contains(session.id) {
            context.delete(session)
        }
        UserDefaults.standard.removeObject(forKey: idsKey)
    }

    private static func storedIDs() -> [String] {
        UserDefaults.standard.stringArray(forKey: idsKey) ?? []
    }
}

#endif
