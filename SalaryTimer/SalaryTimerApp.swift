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

            Tab("Profile", systemImage: "person.crop.circle") {
                ProfileView()
                    .toolbar(tabBarVisibility, for: .tabBar)
            }
        }
    }
}

// MARK: - Meter Tab Background

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

// MARK: - Records Tab Background

struct RecordsBackground: View {
    let isRunning: Bool
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.05, blue: 0.15),
                    Color(red: 0.15, green: 0.10, blue: 0.20),
                    Color(red: 0.12, green: 0.08, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            Circle()
                .fill(Color.purple.opacity(isRunning ? 0.35 : 0.25))
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(x: -100, y: -200)
            
            Circle()
                .fill(Color.yellow.opacity(isRunning ? 0.20 : 0.12))
                .frame(width: 240, height: 240)
                .blur(radius: 100)
                .offset(x: 130, y: -80)
            
            Circle()
                .fill(Color.indigo.opacity(isRunning ? 0.30 : 0.20))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: -140, y: 240)
        }
        .animation(.easeInOut(duration: 0.6), value: isRunning)
    }
}

// MARK: - Profile Tab Background

struct ProfileBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.12, blue: 0.10),
                    Color(red: 0.12, green: 0.18, blue: 0.15),
                    Color(red: 0.10, green: 0.16, blue: 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            Circle()
                .fill(Color.green.opacity(0.22))
                .frame(width: 300, height: 300)
                .blur(radius: 85)
                .offset(x: 110, y: -180)
            
            Circle()
                .fill(Color.teal.opacity(0.18))
                .frame(width: 260, height: 260)
                .blur(radius: 95)
                .offset(x: -120, y: -100)
            
            Circle()
                .fill(Color.mint.opacity(0.15))
                .frame(width: 340, height: 340)
                .blur(radius: 100)
                .offset(x: 100, y: 250)
        }
    }
}
