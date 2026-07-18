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

@Observable
final class SalaryTimerStore {
    var isRunning: Bool = false
    var selectedTab: AppTab = .meter
}

enum AppTab: Hashable {
    case meter
    case records
    case profile
}

struct RootTabView: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(SalaryTimerStore.self) private var timerStore
    @State private var selection: AppTab = .meter

    private var tabBarVisibility: Visibility {
        verticalSizeClass == .compact ? .hidden : .automatic
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab("Meter", systemImage: "timer", value: .meter) {
                ContentView()
                    .toolbar(tabBarVisibility, for: .tabBar)
            }

            Tab("Records", systemImage: "trophy", value: .records) {
                SessionLogView()
                    .toolbar(tabBarVisibility, for: .tabBar)
            }

            Tab("Profile", systemImage: "person.crop.circle", value: .profile) {
                ProfileView()
                    .toolbar(tabBarVisibility, for: .tabBar)
            }
        }
        .onChange(of: selection) { _, newValue in
            timerStore.selectedTab = newValue
        }
        .onAppear {
            timerStore.selectedTab = selection
        }
    }
}

// MARK: - Unified Dynamic Background

struct UnifiedBackground: View {
    let selectedTab: AppTab
    let isRunning: Bool
    
    private struct BackgroundColors {
        let gradient1: Color
        let gradient2: Color
        let gradient3: Color
        let circle1Color: Color
        let circle1Opacity: Double
        let circle2Color: Color
        let circle2Opacity: Double
        let circle3Color: Color
        let circle3Opacity: Double
    }
    
    private var colors: BackgroundColors {
        switch selectedTab {
        case .meter:
            let topColor = isRunning ? Color.red : Color.cyan
            let bottomColor = isRunning ? Color.red : Color.orange
            return BackgroundColors(
                gradient1: Color(red: 0.05, green: 0.09, blue: 0.16),
                gradient2: Color(red: 0.11, green: 0.16, blue: 0.24),
                gradient3: Color(red: 0.20, green: 0.15, blue: 0.11),
                circle1Color: topColor,
                circle1Opacity: 0.50,
                circle2Color: .white,
                circle2Opacity: isRunning ? 0.25 : 0.10,
                circle3Color: bottomColor,
                circle3Opacity: isRunning ? 0.40 : 0.15
            )
            
        case .records:
            return BackgroundColors(
                gradient1: Color(red: 0.10, green: 0.05, blue: 0.15),
                gradient2: Color(red: 0.15, green: 0.10, blue: 0.20),
                gradient3: Color(red: 0.12, green: 0.08, blue: 0.18),
                circle1Color: .purple,
                circle1Opacity: isRunning ? 0.35 : 0.25,
                circle2Color: .yellow,
                circle2Opacity: isRunning ? 0.20 : 0.12,
                circle3Color: .indigo,
                circle3Opacity: isRunning ? 0.30 : 0.20
            )
            
        case .profile:
            return BackgroundColors(
                gradient1: Color(red: 0.08, green: 0.12, blue: 0.10),
                gradient2: Color(red: 0.12, green: 0.18, blue: 0.15),
                gradient3: Color(red: 0.10, green: 0.16, blue: 0.14),
                circle1Color: .green,
                circle1Opacity: 0.22,
                circle2Color: .teal,
                circle2Opacity: 0.18,
                circle3Color: .mint,
                circle3Opacity: 0.15
            )
        }
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [colors.gradient1, colors.gradient2, colors.gradient3],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            Circle()
                .fill(colors.circle1Color.opacity(colors.circle1Opacity))
                .frame(width: selectedTab == .profile ? 300 : selectedTab == .records ? 280 : 320)
                .blur(radius: selectedTab == .profile ? 85 : selectedTab == .records ? 80 : 70)
                .offset(
                    x: selectedTab == .profile ? 110 : selectedTab == .records ? -100 : -120,
                    y: selectedTab == .profile ? -180 : selectedTab == .records ? -200 : -220
                )
            
            Circle()
                .fill(colors.circle2Color.opacity(colors.circle2Opacity))
                .frame(width: selectedTab == .profile ? 260 : selectedTab == .records ? 240 : 280)
                .blur(radius: selectedTab == .profile ? 95 : selectedTab == .records ? 100 : 90)
                .offset(
                    x: selectedTab == .profile ? -120 : selectedTab == .records ? 130 : 140,
                    y: selectedTab == .profile ? -100 : selectedTab == .records ? -80 : -120
                )
            
            Circle()
                .fill(colors.circle3Color.opacity(colors.circle3Opacity))
                .frame(width: selectedTab == .profile ? 340 : selectedTab == .records ? 320 : 360)
                .blur(radius: selectedTab == .profile ? 100 : selectedTab == .records ? 90 : 110)
                .offset(
                    x: selectedTab == .profile ? 100 : selectedTab == .records ? -140 : 120,
                    y: selectedTab == .profile ? 250 : selectedTab == .records ? 240 : 260
                )
        }
        .animation(.smooth(duration: 3, extraBounce: 0), value: selectedTab)
        .animation(.smooth(duration: 0.8, extraBounce: 0), value: isRunning)
    }
}

// MARK: - Legacy Backgrounds (for backwards compatibility)

struct AmbientBackground: View {
    let isRunning: Bool
    @Environment(SalaryTimerStore.self) private var timerStore

    var body: some View {
        UnifiedBackground(selectedTab: timerStore.selectedTab, isRunning: isRunning)
    }
}

struct RecordsBackground: View {
    let isRunning: Bool
    @Environment(SalaryTimerStore.self) private var timerStore
    
    var body: some View {
        UnifiedBackground(selectedTab: timerStore.selectedTab, isRunning: isRunning)
    }
}

struct ProfileBackground: View {
    @Environment(SalaryTimerStore.self) private var timerStore
    
    var body: some View {
        UnifiedBackground(selectedTab: timerStore.selectedTab, isRunning: false)
    }
}

// MARK: - Previews

#Preview {
    RootTabView()
        .environment(SalaryTimerStore())
        .modelContainer(for: SalarySession.self, inMemory: true)
}
