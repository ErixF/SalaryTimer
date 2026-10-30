//
//  ContentView.swift
//  SalaryTimer
//
//  Created by Eric Feng on 5/20/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    // MARK: - Persisted income settings (owned by the Profile tab)
    @AppStorage(ProfileKeys.incomeType) private var incomeType: Int = 0
    @AppStorage(ProfileKeys.hourlyRate) private var hourlyRateText: String = ""
    @AppStorage(ProfileKeys.monthlyIncome) private var monthlyIncomeText: String = ""
    @AppStorage(ProfileKeys.taxRate) private var taxRateText: String = ""
    @AppStorage(ProfileKeys.hoursPerDay) private var hoursPerDayText: String = ""
    @AppStorage(ProfileKeys.daysPerMonth) private var daysPerMonthText: String = ""

    // MARK: - Local UI state
    @State private var showPopup = false
    @State private var resetTapCount = 0
    @State private var lastResetTapDate: Date? = nil
    @State private var titleIndex = 0

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(SalaryTimerStore.self) private var timerStore

    /// Size of the invisible top-right area that triggers the hidden reset.
    private let hiddenResetAreaSize: CGFloat = 64
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

    private var rates: RateCalculator {
        RateCalculator(
            incomeType: incomeType,
            hourlyRateText: hourlyRateText,
            monthlyIncomeText: monthlyIncomeText,
            hoursPerDayText: hoursPerDayText,
            daysPerMonthText: daysPerMonthText,
            deductionText: taxRateText
        )
    }

    /// Net earning per second: the locked segment rate while running, otherwise the Profile rate
    /// (which is what the next Start/Resume will use).
    private var earningPerSecond: Double {
        timerStore.isRunning ? timerStore.segmentNetPerSecond : rates.netPerSecond
    }

    private var isRunning: Bool {
        timerStore.isRunning
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

    /// `MM:SS`, or `H:MM:SS` once past an hour.
    private func elapsedClockText(_ elapsed: TimeInterval) -> String {
        let totalSeconds = max(0, Int(elapsed))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func amountText(_ amount: Double) -> String {
        "$\(amount.formatted(.number.precision(.fractionLength(2))))"
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    AmbientBackground(isRunning: isRunning)
                        .ignoresSafeArea()

                    // Values are derived from timestamps, so a 1s timeline is all the ticking needed.
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        if geo.size.height >= geo.size.width {
                            portraitLayout(now: timeline.date)
                        } else {
                            landscapeLayout(width: geo.size.width, now: timeline.date)
                        }
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                hiddenResetArea
            }
            .alert("RESET APP", isPresented: $showPopup) {
                Button("OK", action: resetApp)
            }
        }
    }

    private func portraitLayout(now: Date) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                screenTitle
                heroSection(now: now)
                controlSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .safeAreaPadding(.top, 8)
    }

    private func landscapeLayout(width: CGFloat, now: Date) -> some View {
        Group {
            if width < 1000 {
                ZStack {
                    Color.black
                        .ignoresSafeArea()

                    VStack(spacing: 18) {
                        landscapeAmount(now: now)

                        if width > 700 {
                            Text(elapsedClockText(timerStore.elapsed(at: now)))
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

    private func heroSection(now: Date) -> some View {
        VStack(spacing: 18) {
            VStack(spacing: 12) {
                Text(amountText(timerStore.netEarned(at: now)))
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(heroPrimaryTextColor)

                Text(elapsedClockText(timerStore.elapsed(at: now)))
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

    private func landscapeAmount(now: Date) -> some View {
        Text(amountText(timerStore.netEarned(at: now)))
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

    /// Idle = Start. Running = Pause. Paused = Resume + Archive & Reset.
    /// Restyled in Phase 2; this phase only switches the logic over.
    private var controlSection: some View {
        HStack(spacing: 12) {
            switch timerStore.state {
            case .idle:
                Button { timerStore.start() } label: {
                    controlLabel("Start", systemImage: "play.fill")
                }
                .controlButtonStyle(prominent: true, tint: .blue)
            case .running:
                Button { timerStore.pause() } label: {
                    controlLabel("Pause", systemImage: "pause.fill")
                }
                .controlButtonStyle(prominent: false, tint: .primary)
            case .paused:
                Button { timerStore.start() } label: {
                    controlLabel("Resume", systemImage: "play.fill")
                }
                .controlButtonStyle(prominent: true, tint: .green)

                Button { timerStore.archiveAndReset(in: modelContext) } label: {
                    controlLabel("Archive & Reset", systemImage: "archivebox.fill")
                }
                .controlButtonStyle(prominent: false, tint: .primary)
            }
        }
    }

    private func controlLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Hidden reset

    /// Invisible tap target in the top-right corner. 10 quick taps open the reset alert.
    private var hiddenResetArea: some View {
        Color.clear
            .frame(width: hiddenResetAreaSize, height: hiddenResetAreaSize)
            .contentShape(Rectangle())
            .onTapGesture(perform: registerHiddenResetTap)
            .accessibilityHidden(true)
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

    /// Saves any metered time, resets the meter, and clears all Profile inputs.
    private func resetApp() {
        timerStore.resetAll(in: modelContext)
        incomeType = 0
        hourlyRateText = ""
        monthlyIncomeText = ""
        taxRateText = ""
        hoursPerDayText = ""
        daysPerMonthText = ""
        resetTapCount = 0
        lastResetTapDate = nil
    }
}

#Preview {
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
