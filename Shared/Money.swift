//
//  Money.swift
//  SalaryTimer
//
//  Created by Eric Feng on 10/30/26.
//

import Foundation

/// Formats amounts with the user's chosen currency symbol, always placed before the number.
/// The symbol is a label only — no conversion. Shared by the app and the widget extension.
enum Money {
    static let defaultSymbol = "$"
    static let symbols = ["$", "€", "£", "¥", "₹", "₩", "₽", "₺", "₱", "฿", "R$", "kr", "CHF"]

    /// `$12.50`, `€12.50`, `kr 12.50` (letter symbols get a space).
    static func string(_ value: Double, symbol: String, fractionDigits: ClosedRange<Int> = 2...2) -> String {
        let number = value.formatted(.number.precision(.fractionLength(fractionDigits)))
        let separator = symbol.last?.isLetter == true ? " " : ""
        return "\(symbol)\(separator)\(number)"
    }
}
