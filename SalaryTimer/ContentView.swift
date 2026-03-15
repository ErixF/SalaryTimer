//
//  ContentView.swift
//  SalaryTimer
//
//  Created by Eric Feng on 5/20/25.
//

import SwiftUI
import UIKit
import ActivityKit

struct ContentView: View {
    // MARK: - Inputs
    @State private var incomeType = 0              // 0 = hourly, 1 = monthly
    @State private var hourlyRateText: String = ""
    @State private var monthlyIncomeText: String = ""
    @State private var taxRateText: String = ""
    @State private var hoursPerDayText: String = ""
    @State private var daysPerMonthText: String = ""
    @State private var showPopup = false
    @State private var showConfiguration = true

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Timer
    @State private var elapsed: TimeInterval = 0
    @State private var timer: Timer? = nil
    @State private var lastStart: Date? = nil

    private var hourlyRate: Double { Double(hourlyRateText) ?? 0 }
    private var monthlyIncome: Double { Double(monthlyIncomeText) ?? 0 }
    private var taxRate: Double { Double(taxRateText) ?? 0 }
    private var hoursPerDay: Double { Double(hoursPerDayText) ?? 0 }
    private var daysPerMonth: Double { Double(daysPerMonthText) ?? 0 }

    /// Net earning per second, after tax.
    private var earningPerSecond: Double {
        if incomeType == 0 {
            let netHourly = hourlyRate * (1 - taxRate / 100)
            return netHourly / 3600
        } else {
            let netMonthly = monthlyIncome * (1 - taxRate / 100)
            let totalSeconds = daysPerMonth * hoursPerDay * 3600
            return totalSeconds > 0 ? netMonthly / totalSeconds : 0
        }
    }

    /// Total earned so far.
    private var totalEarned: Double {
        elapsed * earningPerSecond
    }

    private var isRunning: Bool {
        timer != nil
    }

    private var accentColor: Color {
        isRunning ? .orange : .cyan
    }

    private var elapsedClockText: String {
        let totalSeconds = Int(elapsed)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    ambientBackground

                    if geo.size.height >= geo.size.width {
                        portraitLayout
                    } else {
                        landscapeLayout(width: geo.size.width)
                    }
                }
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                }
            }
            .navigationTitle("Touch Fish")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if verticalSizeClass == .regular {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showPopup = true
                        } label: {
                            Image(systemName: "questionmark.circle")
                        }
                    }
                }
            }
            .toolbarBackground(.automatic, for: .navigationBar)
            .alert("RESET APP", isPresented: $showPopup) {
                Button("OK", action: resetApp)
            }
        }
    }

    private var ambientBackground: some View {
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
                .fill(accentColor.opacity(0.30))
                .frame(width: 320, height: 320)
                .blur(radius: 70)
                .offset(x: -120, y: -220)

            Circle()
                .fill(Color.white.opacity(isRunning ? 0.16 : 0.10))
                .frame(width: 280, height: 280)
                .blur(radius: 90)
                .offset(x: 140, y: -120)

            Circle()
                .fill(Color.orange.opacity(isRunning ? 0.24 : 0.12))
                .frame(width: 360, height: 360)
                .blur(radius: 110)
                .offset(x: 120, y: 260)
        }
        .animation(.easeInOut(duration: 0.6), value: isRunning)
    }

    private var portraitLayout: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                heroSection
                controlSection
                configurationSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .safeAreaPadding(.top, 12)
    }

    private func landscapeLayout(width: CGFloat) -> some View {
        Group {
            if width < 1000 {
                HStack(spacing: 24) {
                    heroSection
                        .frame(maxWidth: .infinity)

                    VStack(spacing: 18) {
                        controlSection
                        configurationSection
                    }
                    .frame(maxWidth: 360)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            } else {
                Text("Go get an iPhone")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var heroSection: some View {
        VStack(spacing: 18) {
            Text(isRunning ? "Clocked In" : "Ready To Drift")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.78))

            VStack(spacing: 10) {
                Text(totalEarned, format: .currency(code: "CAD"))
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(.white)

                Text(elapsedClockText)
                    .font(.title3.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.72))
            }

            rateChip
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .heroSurface()
    }

    private var rateChip: some View {
        HStack(spacing: 4) {
            Text("≈")
            Text(earningPerSecond, format: .currency(code: "CAD").precision(.fractionLength(4)))
                .monospacedDigit()
            Text("/ sec")
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.white.opacity(0.78))
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.10), in: Capsule())
    }

    private var controlSection: some View {
        HStack(spacing: 12) {
            Button(action: startTimer) {
                Label(isRunning ? "Running" : "Start", systemImage: isRunning ? "play.fill" : "play.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .controlButtonStyle(prominent: true, tint: accentColor)
            .disabled(isRunning)

            Button(action: stopTimer) {
                Label("Stop", systemImage: "pause.fill")
                    .frame(maxWidth: .infinity)
            }
            .controlButtonStyle(prominent: false, tint: .red)
            .disabled(!isRunning)

            Button(action: resetTimer) {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .controlButtonStyle(prominent: false, tint: .orange)
        }
    }

    private var configurationSection: some View {
        VStack(spacing: 16) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                    showConfiguration.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Session Setup")
                            .font(.headline)
                        Text("Adjust rate, tax, and work assumptions.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: showConfiguration ? "chevron.down.circle.fill" : "slider.horizontal.3")
                        .font(.title3)
                        .foregroundStyle(accentColor)
                }
            }
            .buttonStyle(.plain)

            if showConfiguration {
                VStack(spacing: 0) {
                    Picker("", selection: $incomeType) {
                        Text("Hourly").tag(0)
                        Text("Monthly").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, 18)

                    settingsRow(title: incomeType == 0 ? "Hourly $" : "Monthly $") {
                        if incomeType == 0 {
                            amountField("28", text: $hourlyRateText)
                        } else {
                            amountField("4000", text: $monthlyIncomeText)
                        }
                    }

                    dividerLine

                    settingsRow(title: "Tax %") {
                        amountField("11", text: $taxRateText)
                    }

                    if incomeType == 1 {
                        dividerLine

                        settingsRow(title: "Hours / Day") {
                            amountField("7", text: $hoursPerDayText)
                        }

                        dividerLine

                        settingsRow(title: "Days / Month") {
                            amountField("22", text: $daysPerMonthText)
                        }
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .panelSurface()
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(height: 1)
    }

    private func settingsRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)

            Spacer()

            content()
        }
        .padding(.vertical, 14)
    }

    private func amountField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .multilineTextAlignment(.trailing)
            .keyboardType(.decimalPad)
            .font(.body.monospacedDigit())
            .frame(minWidth: 72)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Color.white.opacity(colorScheme == .dark ? 0.08 : 0.42),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
    }

    // MARK: - Timer controls
    private func startTimer() {
        guard timer == nil else { return }
        lastStart = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if let start = lastStart {
                elapsed += Date().timeIntervalSince(start)
                lastStart = Date()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        lastStart = nil
    }

    private func resetTimer() {
        stopTimer()
        elapsed = 0
    }

    /// Reset all inputs and timer to initial state.
    private func resetApp() {
        stopTimer()
        incomeType = 0
        hourlyRateText = ""
        monthlyIncomeText = ""
        taxRateText = ""
        hoursPerDayText = ""
        daysPerMonthText = ""
        elapsed = 0
    }
}

#Preview {
    ContentView()
}

private extension View {
    @ViewBuilder
    func heroSurface() -> some View {
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.regular.tint(.white.opacity(0.08)).interactive(), in: .rect(cornerRadius: 32))
        } else {
            self
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }
        }
    }

    @ViewBuilder
    func panelSurface() -> some View {
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.regular.tint(.white.opacity(0.05)), in: .rect(cornerRadius: 28))
        } else {
            self
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                }
        }
    }

    @ViewBuilder
    func controlButtonStyle(prominent: Bool, tint: Color) -> some View {
        if #available(iOS 26.0, *) {
            if prominent {
                self
                    .font(.headline)
                    .padding(.vertical, 14)
                    .buttonStyle(GlassProminentButtonStyle())
            } else {
                self
                    .font(.headline)
                    .padding(.vertical, 14)
                    .buttonStyle(GlassButtonStyle())
                    .tint(tint)
            }
        } else {
            if prominent {
                self
                    .font(.headline)
                    .padding(.vertical, 14)
                    .buttonStyle(BorderedProminentButtonStyle())
                    .tint(tint)
            } else {
                self
                    .font(.headline)
                    .padding(.vertical, 14)
                    .buttonStyle(BorderedButtonStyle())
                    .tint(tint)
            }
        }
    }
}
