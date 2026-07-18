//
//  ContentView.swift
//  SalaryTimer
//
//  Created by Eric Feng on 5/20/25.
//

import SwiftUI
import ActivityKit
import SwiftData

struct ContentView: View {
    // MARK: - Persisted income settings (owned by the Profile tab)
    @AppStorage("profile.incomeType") private var incomeType: Int = 0
    @AppStorage("profile.hourlyRate") private var hourlyRateText: String = ""
    @AppStorage("profile.monthlyIncome") private var monthlyIncomeText: String = ""
    @AppStorage("profile.taxRate") private var taxRateText: String = ""
    @AppStorage("profile.hoursPerDay") private var hoursPerDayText: String = ""
    @AppStorage("profile.daysPerMonth") private var daysPerMonthText: String = ""

    // MARK: - Local UI state
    @State private var showPopup = false
    @State private var resetTapCount = 0
    @State private var lastResetTapDate: Date? = nil
    @State private var titleIndex = 0

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(SalaryTimerStore.self) private var timerStore

    // MARK: - Timer
    @State private var elapsed: TimeInterval = 0
    @State private var timer: Timer? = nil
    @State private var lastStart: Date? = nil
    @State private var liveActivity: Activity<SalaryTimerAttributes>? = nil
    @State private var liveActivitySessionStartDate: Date? = nil
    @State private var lastLiveActivityRefreshDate: Date? = nil
    @State private var lastLiveActivityRate: Double = 0

    private var hourlyRate: Double { Double(hourlyRateText) ?? 0 }
    private var monthlyIncome: Double { Double(monthlyIncomeText) ?? 0 }
    private var taxRate: Double { Double(taxRateText) ?? 0 }
    private var hoursPerDay: Double { Double(hoursPerDayText) ?? 0 }
    private var daysPerMonth: Double { Double(daysPerMonthText) ?? 0 }
    private let liveActivityRefreshInterval: TimeInterval = 15
    private let titleOptions = [
        "Getting Paid to Exist",
        "Clocking In to Breathe",
        "Paid to Occupy Space",
        "Being Alive\nBilled in Seconds",
        "Money Printer:\nWarm-Up Mode",
        "Clock In, Mind Out",
        "Touching Fish Bro",
        "Initiate Bare Minimum Wealth",
        "Money O’Clock",
        "Being Alive, Professionally",
        "Professional Breathing Session"
    ]

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

    private var heroPrimaryTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var heroSecondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.78) : .black.opacity(0.70)
    }

    private var heroChipTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.84) : .black.opacity(0.78)
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
                    AmbientBackground(isRunning: isRunning)
                        .ignoresSafeArea()

                    if geo.size.height >= geo.size.width {
                        portraitLayout
                    } else {
                        landscapeLayout(width: geo.size.width)
                    }
                }
            }
            .alert("RESET APP", isPresented: $showPopup) {
                Button("OK", action: resetApp)
            }
        }
    }

    private var portraitLayout: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                screenTitle
                heroSection
                controlSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .safeAreaPadding(.top, 8)
    }

    private func landscapeLayout(width: CGFloat) -> some View {
        Group {
            if width < 1000 {
                ZStack {
                    Color.black
                        .ignoresSafeArea()

                    VStack(spacing: 18) {
                        landscapeAmount

                        if width > 700 {
                            Text(elapsedClockText)
                                .font(.system(size: 36, weight: .medium, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white.opacity(0.82))
                        }
                    }
                    .padding(.horizontal, 24)
                }
            } else {
                Text("Go get an iPhone")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var screenTitle: some View {
        Text(titleOptions[titleIndex])
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.96))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.72)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .center)
            .padding(.bottom, 4)
            .contentTransition(.opacity)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    titleIndex = (titleIndex + 1) % titleOptions.count
                }
            }
    }

    private var heroSection: some View {
        VStack(spacing: 18) {
            VStack(spacing: 12) {
                Text("$\(totalEarned.formatted(.number.precision(.fractionLength(2))))")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(heroPrimaryTextColor)

                Text(elapsedClockText)
                    .font(.title3.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(heroSecondaryTextColor)
            }

            rateChip
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .heroSurface()
    }

    private var landscapeAmount: some View {
        Text("$\(totalEarned.formatted(.number.precision(.fractionLength(2))))")
            .font(.system(size: 150, weight: .bold, design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.35)
            .lineLimit(1)
            .foregroundStyle(.white.opacity(0.82))
            .padding(.horizontal, 24)
    }

    private var rateChip: some View {
        HStack(spacing: 4) {
            Text("≈")
            Text("$\(earningPerSecond.formatted(.number.precision(.fractionLength(4))))")
                .monospacedDigit()
            Text("/ sec")
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(heroChipTextColor)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            colorScheme == .dark ? Color.white.opacity(0.14) : Color.white.opacity(0.28),
            in: Capsule()
        )
    }

    private var controlSection: some View {
        HStack(spacing: 12) {
            Button(action: startTimer) {
                Label(isRunning ? "Running" : "Start", systemImage: isRunning ? "play.fill" : "play.circle.fill")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity)
            }
            .controlButtonStyle(prominent: true, tint: accentColor)
            .disabled(isRunning)

            Button(action: stopTimer) {
                Label("Pause", systemImage: "pause.fill")
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity)
            }
            .controlButtonStyle(prominent: false, tint: .red)
            .disabled(!isRunning)

            Button(action: resetTimer) {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity)
            }
            .controlButtonStyle(prominent: false, tint: .orange)
            .simultaneousGesture(
                TapGesture().onEnded {
                    registerHiddenResetTap()
                }
            )
        }
    }

    // MARK: - Timer controls
    private func startTimer() {
        guard timer == nil else { return }
        let now = Date()
        lastStart = now
        liveActivitySessionStartDate = now.addingTimeInterval(-elapsed)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            commitElapsed()
            refreshLiveActivityIfNeeded()
        }
        startLiveActivity(at: now)
        timerStore.isRunning = true
        timerStore.isPaused = false
    }

    private func stopTimer() {
        let now = Date()
        commitElapsed(to: now)
        timer?.invalidate()
        timer = nil
        lastStart = nil
        endLiveActivity(at: now)
        timerStore.isRunning = false
        timerStore.isPaused = elapsed > 0 // Set paused if there's accumulated time
    }

    private func resetTimer() {
        stopTimer()
        persistSessionIfNeeded()
        elapsed = 0
        timerStore.isPaused = false // Clear paused state when resetting
    }

    private func persistSessionIfNeeded() {
        guard elapsed > 0 else { return }
        let session = SalarySession(
            endDate: Date(),
            totalEarned: totalEarned,
            duration: elapsed,
            unitPrice: earningPerSecond
        )
        modelContext.insert(session)
    }

    private func registerHiddenResetTap() {
        let now = Date()
        if let lastResetTapDate, now.timeIntervalSince(lastResetTapDate) <= 0.8 {
            resetTapCount += 1
        } else {
            resetTapCount = 1
        }

        lastResetTapDate = now

        if resetTapCount >= 10 {
            resetTapCount = 0
            lastResetTapDate = nil
            showPopup = true
        }
    }

    /// Reset all inputs and timer to initial state.
    private func resetApp() {
        stopTimer()
        persistSessionIfNeeded()
        endAllLiveActivities()
        incomeType = 0
        hourlyRateText = ""
        monthlyIncomeText = ""
        taxRateText = ""
        hoursPerDayText = ""
        daysPerMonthText = ""
        elapsed = 0
        resetTapCount = 0
        lastResetTapDate = nil
        liveActivitySessionStartDate = nil
    }

    private func commitElapsed(to now: Date = Date()) {
        guard let start = lastStart else { return }
        elapsed += now.timeIntervalSince(start)
        lastStart = now
    }

    private func currentLiveActivityState(at now: Date) -> SalaryTimerAttributes.ContentState {
        SalaryTimerAttributes.ContentState(
            sessionStartDate: liveActivitySessionStartDate ?? now,
            amountAnchorDate: now,
            startingAmount: totalEarned,
            earningPerSecond: earningPerSecond
        )
    }

    private func startLiveActivity(at now: Date) {
        guard #available(iOS 16.1, *), earningPerSecond > 0 else { return }

        let attributes = SalaryTimerAttributes(currencyCode: "USD")
        let content = ActivityContent(state: currentLiveActivityState(at: now), staleDate: nil)

        Task {
            if let existingActivity = liveActivity {
                await existingActivity.end(nil, dismissalPolicy: ActivityUIDismissalPolicy.immediate)
            }

            do {
                liveActivity = try Activity.request(attributes: attributes, content: content, pushType: nil)
                lastLiveActivityRefreshDate = now
                lastLiveActivityRate = earningPerSecond
            } catch {
                liveActivity = nil
            }
        }
    }

    private func refreshLiveActivityIfNeeded(force: Bool = false) {
        guard #available(iOS 16.1, *), let liveActivity else { return }

        let now = Date()
        let rateChanged = abs(earningPerSecond - lastLiveActivityRate) > 0.000_001
        let isRefreshDue = lastLiveActivityRefreshDate.map { now.timeIntervalSince($0) >= liveActivityRefreshInterval } ?? true

        guard force || rateChanged || isRefreshDue else { return }

        let content = ActivityContent(state: currentLiveActivityState(at: now), staleDate: nil)

        Task {
            await liveActivity.update(content)
            lastLiveActivityRefreshDate = now
            lastLiveActivityRate = earningPerSecond
        }
    }

    private func endLiveActivity(at now: Date) {
        guard #available(iOS 16.1, *) else { return }
        guard let liveActivity else {
            lastLiveActivityRefreshDate = nil
            lastLiveActivityRate = 0
            return
        }

        let content = ActivityContent(state: currentLiveActivityState(at: now), staleDate: now)

        Task {
            await liveActivity.end(content, dismissalPolicy: ActivityUIDismissalPolicy.immediate)
            self.liveActivity = nil
            liveActivitySessionStartDate = nil
            lastLiveActivityRefreshDate = nil
            lastLiveActivityRate = 0
        }
    }

    private func endAllLiveActivities() {
        guard #available(iOS 16.1, *) else { return }

        let activities = Activity<SalaryTimerAttributes>.activities

        guard !activities.isEmpty else {
            liveActivity = nil
            liveActivitySessionStartDate = nil
            lastLiveActivityRefreshDate = nil
            lastLiveActivityRate = 0
            return
        }

        Task {
            for activity in activities {
                await activity.end(nil, dismissalPolicy: ActivityUIDismissalPolicy.immediate)
            }

            liveActivity = nil
            liveActivitySessionStartDate = nil
            lastLiveActivityRefreshDate = nil
            lastLiveActivityRate = 0
        }
    }
}

#Preview("Root Tab View") {
    RootTabView()
        .environment(SalaryTimerStore())
        .modelContainer(for: SalarySession.self, inMemory: true)
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
    func controlButtonStyle(prominent: Bool, tint: Color) -> some View {
        if #available(iOS 26.0, *) {
            if prominent {
                self
                    .font(.headline)
                    .padding(.vertical, 10)
                    .buttonStyle(GlassProminentButtonStyle())
            } else {
                self
                    .font(.headline)
                    .padding(.vertical, 10)
                    .buttonStyle(GlassButtonStyle())
                    .tint(tint)
            }
        } else {
            if prominent {
                self
                    .font(.headline)
                    .padding(.vertical, 10)
                    .buttonStyle(BorderedProminentButtonStyle())
                    .tint(tint)
            } else {
                self
                    .font(.headline)
                    .padding(.vertical, 10)
                    .buttonStyle(BorderedButtonStyle())
                    .tint(tint)
            }
        }
    }
}
