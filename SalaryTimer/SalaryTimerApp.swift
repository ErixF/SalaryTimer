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
}

struct RootTabView: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var tabBarVisibility: Visibility {
        verticalSizeClass == .compact ? .hidden : .automatic
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
        }
    }
}

struct AmbientBackground: View {
    let isRunning: Bool

    private var topCircleColor: Color { isRunning ? .red : .cyan }
    private var bottomCircleColor: Color { isRunning ? .red : .orange }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.09, blue: 0.16),
                    Color(red: 0.11, green: 0.16, blue: 0.24),
                    Color(red: 0.20, green: 0.15, blue: 0.11)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(topCircleColor.opacity(0.50))
                .frame(width: 320, height: 320)
                .blur(radius: 70)
                .offset(x: -120, y: -220)

            Circle()
                .fill(Color.white.opacity(isRunning ? 0.25 : 0.10))
                .frame(width: 280, height: 280)
                .blur(radius: 90)
                .offset(x: 140, y: -120)

            Circle()
                .fill(bottomCircleColor.opacity(isRunning ? 0.40 : 0.15))
                .frame(width: 360, height: 360)
                .blur(radius: 110)
                .offset(x: 120, y: 260)
        }
        .animation(.easeInOut(duration: 0.6), value: isRunning)
    }
}
