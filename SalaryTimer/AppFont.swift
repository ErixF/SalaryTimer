//
//  AppFont.swift
//  SalaryTimer
//
//  Created by Eric Feng on 11/17/26.
//

import SwiftUI

/// Role-based type for the app. The iOS text styles already form a ~×1.2 scale
/// (11 · 12 · 13 · 15 · 17 · 20 · 22 · 34), so each role maps onto one and scales with Dynamic Type.
/// The Meter hero sizes (amount, title, timer, rate line) use `@ScaledMetric` in `ContentView`
/// because they're multiplied for wide portrait. Fixed sizes remain only in the capped landscape
/// meter, the Settings icon glyph and the Welcome icon.
enum AppFont {
    /// Uppercase tracked labels: card labels, captions (11).
    static let label = Font.caption2.weight(.bold)
    /// Meter state chip (12).
    static let chip = Font.caption.weight(.bold)
    /// Card, tile and row amounts (20).
    static let value = Font.system(.title3, design: .rounded).weight(.bold)
    /// Records summary values; one step down so all three fit a third of a phone width (17).
    static let summaryValue = Font.system(.headline, design: .rounded).weight(.bold)

    /// Tracking for `label`.
    static let labelTracking: CGFloat = 0.8
}
