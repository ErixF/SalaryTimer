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
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(for: SalarySession.self)
    }
}

struct RootTabView: View {
    var body: some View {
        TabView {
            Tab("Meter", systemImage: "timer") {
                ContentView()
            }

            Tab("Records", systemImage: "trophy") {
                SessionLogView()
            }
        }
    }
}
