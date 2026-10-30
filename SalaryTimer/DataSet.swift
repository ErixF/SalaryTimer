//
//  DataSet.swift
//  SalaryTimer
//
//  Created by Eric Feng on 3/24/26.
//

import Foundation
import SwiftData

@Model
final class SalarySession {
    var id: UUID
    var endDate: Date
    var totalEarned: Double
    var duration: TimeInterval
    /// Average net earned per second across the session.
    var unitPrice: Double
    /// Optional so records saved before v2.3 migrate automatically.
    var startDate: Date?
    var grossEarned: Double?

    init(
        id: UUID = UUID(),
        endDate: Date,
        totalEarned: Double,
        duration: TimeInterval,
        unitPrice: Double,
        startDate: Date? = nil,
        grossEarned: Double? = nil
    ) {
        self.id = id
        self.endDate = endDate
        self.totalEarned = totalEarned
        self.duration = duration
        self.unitPrice = unitPrice
        self.startDate = startDate
        self.grossEarned = grossEarned
    }
}
