//
//  SalaryTimerApp.swift
//  SalaryTimer
//
//  Created by Eric Feng on 5/20/25.
//

import SwiftUI
import SwiftData

@main
struct SalaryTimerApp: App {
    @State private var timerStore = SalaryTimerStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(timerStore)
        }
        .modelContainer(for: SalarySession.self)
    }
}

struct RootTabView: View {
    /// True when the window is wider than tall, below the iPad-size cutoff the Meter uses.
    /// Based on shape rather than size class so larger landscape screens (e.g. iPhone Duo inner
    /// display) also hide the tab bar, while iPad keeps it so it never gets stuck.
    @State private var isPhoneLandscape = false

    private var tabBarVisibility: Visibility {
        isPhoneLandscape ? .hidden : .automatic
    }

    var body: some View {
        TabView {
            Tab("Meter", systemImage: "timer") {
                ContentView()
                    .toolbar(tabBarVisibility, for: .tabBar)
            }

            Tab("Records", systemImage: "trophy") {
                SessionLogView()
                    .toolbar(tabBarVisibility, for: .tabBar)
            }

            Tab("Profile", systemImage: "person.crop.circle") {
                ProfileView()
                    .toolbar(tabBarVisibility, for: .tabBar)
            }
        }
        .onGeometryChange(for: Bool.self) { proxy in
            proxy.size.width > proxy.size.height && proxy.size.width < 1000
        } action: { isLandscape in
            isPhoneLandscape = isLandscape
        }
    }
}

/// Meter backdrop. Idle = blue, Running = green, Paused = dimmer green.
/// Each state is its own layer so changes crossfade smoothly.
struct AmbientBackground: View {
    let state: MeterState

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            layer(for: .idle).opacity(state == .idle ? 1 : 0)
            layer(for: .running).opacity(state == .running ? 1 : 0)
            layer(for: .paused).opacity(state == .paused ? 1 : 0)
        }
        .animation(.easeInOut(duration: 0.6), value: state)
    }

    private func layer(for state: MeterState) -> some View {
        let palette = Palette(state: state, isDark: colorScheme == .dark)
        return ZStack {
            LinearGradient(colors: palette.base, startPoint: .top, endPoint: .bottom)
            RadialGradient(
                colors: [palette.topGlow, palette.topGlow.opacity(0)],
                center: UnitPoint(x: 0.15, y: 0),
                startRadius: 0,
                endRadius: 520
            )
            if let bottomGlow = palette.bottomGlow {
                RadialGradient(
                    colors: [bottomGlow, bottomGlow.opacity(0)],
                    center: UnitPoint(x: 0.9, y: 1.05),
                    startRadius: 0,
                    endRadius: 460
                )
            }
        }
    }

    private struct Palette {
        let base: [Color]
        let topGlow: Color
        let bottomGlow: Color?

        init(state: MeterState, isDark: Bool) {
            switch (state, isDark) {
            case (.idle, true):
                base = [Color(hex: 0x0A2036), Color(hex: 0x081426), Color(hex: 0x0A101D)]
                topGlow = Color(red: 38 / 255, green: 132 / 255, blue: 199 / 255).opacity(0.85)
                bottomGlow = Color(red: 214 / 255, green: 120 / 255, blue: 40 / 255).opacity(0.28)
            case (.running, true):
                base = [Color(hex: 0x07231A), Color(hex: 0x071A14), Color(hex: 0x081410)]
                topGlow = Color(red: 24 / 255, green: 160 / 255, blue: 88 / 255).opacity(0.8)
                bottomGlow = Color(red: 16 / 255, green: 110 / 255, blue: 60 / 255).opacity(0.35)
            case (.paused, true):
                base = [Color(hex: 0x0A1F18), Color(hex: 0x0A1712), Color(hex: 0x0A1210)]
                topGlow = Color(red: 24 / 255, green: 140 / 255, blue: 80 / 255).opacity(0.45)
                bottomGlow = nil
            case (.idle, false):
                base = [Color(hex: 0xDCEBFA), Color(hex: 0xEDF3FA), Color(hex: 0xF5F7FA)]
                topGlow = Color(red: 38 / 255, green: 132 / 255, blue: 199 / 255).opacity(0.35)
                bottomGlow = Color(red: 214 / 255, green: 120 / 255, blue: 40 / 255).opacity(0.14)
            case (.running, false):
                base = [Color(hex: 0xDDF3E5), Color(hex: 0xEDF7F0), Color(hex: 0xF4F8F5)]
                topGlow = Color(red: 24 / 255, green: 160 / 255, blue: 88 / 255).opacity(0.35)
                bottomGlow = Color(red: 16 / 255, green: 110 / 255, blue: 60 / 255).opacity(0.14)
            case (.paused, false):
                base = [Color(hex: 0xE6EFE9), Color(hex: 0xF0F4F1), Color(hex: 0xF5F7F5)]
                topGlow = Color(red: 24 / 255, green: 140 / 255, blue: 80 / 255).opacity(0.2)
                bottomGlow = nil
            }
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
