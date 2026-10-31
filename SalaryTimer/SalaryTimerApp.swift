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
    enum AppTab: Hashable {
        case home, meter, records, settings
    }

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @AppStorage(ProfileKeys.alternativeLook) private var alternativeLook = false

    @State private var selection: AppTab = .meter
    @State private var showsSettingsSheet = false
    @State private var isLandscape = false
    /// Changed whenever the user leaves the Settings tab, which rebuilds it on its root list.
    @State private var settingsResetID = UUID()

    /// Alternative Look on a wide landscape screen (Duo inner landscape, iPad landscape): Home
    /// combines Records and the Meter, the menu is hidden, and Settings is a side-bar button.
    private var usesHome: Bool {
        alternativeLook && horizontalSizeClass == .regular && verticalSizeClass == .regular && isLandscape
    }

    /// With Alternative Look on, regular width (Duo inner display, iPad) shows Settings as a sheet
    /// over the current tab. Otherwise, and on compact width, Settings is a normal tab page.
    private var settingsIsSheet: Bool { alternativeLook && horizontalSizeClass == .regular }

    private var tabBarVisibility: Visibility {
        // Hidden only behind the black landscape meter (phone landscape, Duo outer landscape).
        verticalSizeClass == .compact ? .hidden : .automatic
    }

    var body: some View {
        Group {
            if usesHome {
                // No menu at all: Home is the only screen, Settings opens from its side bar.
                HomeView(onOpenSettings: { showsSettingsSheet = true })
            } else {
                tabs
            }
        }
        .onChange(of: selection) { previous, current in
            // Leaving the Settings tab: the next visit starts on its root list, not the last page.
            if previous == .settings, current != .settings {
                settingsResetID = UUID()
            }
            // On regular width, the Settings item opens a sheet and the previous tab stays selected.
            guard current == .settings, settingsIsSheet else { return }
            selection = previous
            showsSettingsSheet = true
        }
        .onGeometryChange(for: Bool.self) { proxy in
            proxy.size.width > proxy.size.height
        } action: { landscape in
            isLandscape = landscape
        }
        .onChange(of: usesHome, initial: true) { _, home in
            // Meter/Records ⇄ Home when the menu changes shape; Settings stays where it is.
            if home, selection == .meter || selection == .records {
                selection = .home
            } else if !home, selection == .home {
                selection = .meter
            }
        }
        .onChange(of: horizontalSizeClass) { syncSettingsPresentation() }
        .onChange(of: alternativeLook) { syncSettingsPresentation() }
        .sheet(isPresented: $showsSettingsSheet) {
            SettingsView(isSheet: true)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var tabs: some View {
        TabView(selection: $selection) {
            Tab("Meter", systemImage: "timer", value: AppTab.meter) {
                ContentView()
                    .toolbar(tabBarVisibility, for: .tabBar)
            }

            Tab("Records", systemImage: "trophy", value: AppTab.records) {
                SessionLogView()
                    .toolbar(tabBarVisibility, for: .tabBar)
            }

            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
                    .id(settingsResetID)
                    .toolbar(tabBarVisibility, for: .tabBar)
            }
        }
    }

    /// Keeps Settings open across fold/unfold and Alternative Look changes, swapping page ↔ sheet.
    private func syncSettingsPresentation() {
            if settingsIsSheet, selection == .settings {
                // Unfolding while on the Settings page: keep Settings open, but as a sheet.
                selection = .meter
                showsSettingsSheet = true
            } else if !settingsIsSheet, showsSettingsSheet {
                // Folding while the Settings sheet is open: keep Settings open, but as a page.
                showsSettingsSheet = false
                selection = .settings
            }
    }
}

/// Alternative Look's combined Home: Records on the left third, Meter on the right two-thirds,
/// next to the side bar that holds its actions. When the inner display is half open, each takes
/// one side of the fold instead. There's no menu here; Settings is a side-bar button.
struct HomeView: View {
    let onOpenSettings: @MainActor () -> Void

    private let foldClearance: CGFloat = 16

    var body: some View {
        GeometryReader { geo in
            let fold = geo.verticalFold
            let recordsWidth = fold.map { max(0, $0.minX - foldClearance) } ?? geo.size.width / 3
            let gap = fold.map { $0.width + foldClearance * 2 } ?? 0

            HStack(spacing: 0) {
                SessionLogView(isEmbedded: true)
                    .frame(width: recordsWidth)
                Color.clear
                    .frame(width: gap)
                ContentView(onOpenSettings: onOpenSettings)
                    .frame(maxWidth: .infinity)
            }
        }
        .background { ScreenBackground().ignoresSafeArea() }
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

/// Static backdrop for Records and Profile: deep navy in dark mode, system grouped gray in light.
struct ScreenBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if colorScheme == .dark {
            LinearGradient(
                stops: [
                    .init(color: Color(hex: 0x0A1626), location: 0),
                    .init(color: Color(hex: 0x080D16), location: 0.3),
                    .init(color: Color(hex: 0x070A10), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            Color(.systemGroupedBackground)
        }
    }
}

/// Rounded content card used on Records and Profile; adapts to light/dark.
struct GroupedCard<Content: View>: View {
    @ViewBuilder let content: Content

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            colorScheme == .dark ? Color.white.opacity(0.055) : Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.07) : Color.clear, lineWidth: 1)
        }
    }
}

/// Green-tinted glass confirmation pill, shown at the top of a screen. Taps pass through.
struct ToastView: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .symbolRenderingMode(.multicolor)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .glassEffect(.regular.tint(.green.opacity(0.25)), in: .capsule)
            .padding(.top, 8)
            .allowsHitTesting(false)
    }
}

/// Row fill that matches `GroupedCard` in both appearances (used by Records and Settings).
struct RowBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        colorScheme == .dark ? Color.white.opacity(0.055) : Color(.secondarySystemGroupedBackground)
    }
}

extension GeometryProxy {
    /// The fold when the Duo inner display is half open in portrait (a band across the screen).
    var horizontalFold: CGRect? {
        reservedRegions(kind: .division).first { $0.isActive && $0.frame.width > $0.frame.height }?.frame
    }

    /// The fold when the Duo inner display is half open in landscape (a band down the middle).
    var verticalFold: CGRect? {
        reservedRegions(kind: .division).first { $0.isActive && $0.frame.height > $0.frame.width }?.frame
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
