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
    var unitPrice: Double

    init(
        id: UUID = UUID(),
        endDate: Date,
        totalEarned: Double,
        duration: TimeInterval,
        unitPrice: Double
    ) {
        self.id = id
        self.endDate = endDate
        self.totalEarned = totalEarned
        self.duration = duration
        self.unitPrice = unitPrice
    }
}
