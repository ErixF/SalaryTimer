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
    @AppStorage(ProfileKeys.currencySymbol) private var currencySymbol: String = Money.defaultSymbol
    @AppStorage(ProfileKeys.sessionGoal) private var sessionGoalText: String = ""

    /// Set after the first successful Archive & Reset; hides the first-use hint for good.
    @AppStorage("meter.hasArchived") private var hasArchived = false

    // MARK: - Local UI state
    @State private var showPopup = false
    @State private var resetTapCount = 0
    @State private var lastResetTapDate: Date? = nil
    @State private var titleIndex = 0
    @State private var toastMessage: String? = nil
    @State private var toastTask: Task<Void, Never>? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(SalaryTimerStore.self) private var timerStore
    @Query(sort: \SalarySession.endDate, order: .reverse) private var sessions: [SalarySession]

    /// Size of the invisible top-right area that triggers the hidden reset.
    private let hiddenResetAreaSize: CGFloat = 64
    /// Fixed slot above the buttons so the hint never moves them.
    private let hintSlotHeight: CGFloat = 34
    private let toastDuration: Duration = .milliseconds(2600)
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

    private var state: MeterState { timerStore.state }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    AmbientBackground(state: state)
                        .ignoresSafeArea()

                    // Values are derived from timestamps, so a 1s timeline is all the ticking needed.
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        if geo.size.height >= geo.size.width {
                            portraitLayout(now: timeline.date, height: geo.size.height)
                        } else {
                            landscapeLayout(width: geo.size.width, now: timeline.date)
                        }
                    }
                }
            }
            .overlay(alignment: .top) {
                toast
            }
            .overlay(alignment: .topTrailing) {
                hiddenResetArea
            }
            .alert("RESET APP", isPresented: $showPopup) {
                Button("OK") { resetApp() }
            }
        }
    }

    // MARK: - Portrait

    private func portraitLayout(now: Date, height: CGFloat) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    StateChip(state: state)
                    screenTitle
                }

                heroSection(now: now)
                    .padding(.top, 22)

                detailCard(now: now)
                    .padding(.top, 18)

                statsRow
                    .padding(.top, 18)

                if let goal = SessionGoal.amount(from: sessionGoalText) {
                    GoalCard(
                        earned: timerStore.netEarned(at: now),
                        goal: goal,
                        state: state,
                        format: { amountText($0) }
                    )
                    .padding(.top, 10)
                }

                Spacer(minLength: 18)

                controlSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .frame(minHeight: height)
        }
        .scrollBounceBehavior(.basedOnSize)
        // The meter is a single-screen dashboard; past XXX Large the cards push the
        // controls under the tab bar, so text stops growing there.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var screenTitle: some View {
        Text(titleOptions[titleIndex])
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.72)
            // Reserve two lines so cycling between 1- and 2-line titles doesn't shift the layout.
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .center)
            .contentShape(Rectangle())
            .contentTransition(.opacity)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    titleIndex = (titleIndex + 1) % titleOptions.count
                }
            }
    }

    private func heroSection(now: Date) -> some View {
        let amount = timerStore.netEarned(at: now)
        return VStack(spacing: 6) {
            Text(elapsedClockText(timerStore.elapsed(at: now)))
                .font(.system(size: 17, weight: .semibold))
                .tracking(1.2)
                .monospacedDigit()
                .foregroundStyle(.secondary)

            Text(amountText(amount))
                .font(.system(size: 64, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(.primary)
                .contentTransition(.numericText(value: amount))
                .animation(.snappy, value: amount)

            Text("≈ \(perSecondText(earningPerSecond)) / sec")
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(.primary.opacity(0.1), in: Capsule())
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func detailCard(now: Date) -> some View {
        let netHourly = earningPerSecond * 3600
        return VStack(spacing: 5) {
            Group {
                if rates.hasDeductions {
                    Text("Take-home \(amountText(netHourly))/hr after \(rates.deduction.formatted())% deductions")
                } else {
                    Text("Gross \(amountText(netHourly))/hr — no deductions added")
                }
                if let start = timerStore.sessionStartDate {
                    Text("Started \(start.formatted(.dateTime.hour().minute().second()))")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            if state != .idle {
                Text("At this rate: \(amountText(netHourly)) by the hour")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.green)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentCard(cornerRadius: 16)
    }

    private var statsRow: some View {
        let calendar = Calendar.current
        let today = sessions.filter { calendar.isDateInToday($0.endDate) }
        let todayTotal = today.reduce(0) { $0 + $1.totalEarned }
        let last = sessions.first

        return HStack(spacing: 10) {
            StatTile(
                label: "Today so far",
                value: amountText(todayTotal),
                detail: today.count == 1 ? "1 session" : "\(today.count) sessions"
            )
            StatTile(
                label: "Last session",
                value: last.map { amountText($0.totalEarned) } ?? "—",
                detail: last.map {
                    "\(SessionFormatters.duration($0.duration)) · \($0.endDate.formatted(date: .omitted, time: .shortened))"
                } ?? "Nothing archived yet"
            )
        }
    }

    // MARK: - Controls

    /// Idle = Start. Running = Pause. Paused = Resume + Archive & Reset.
    /// The hint slot is always present so buttons sit at the same height in every state.
    private var controlSection: some View {
        VStack(spacing: 0) {
            Text("“Archive & Reset” saves the current numbers to Records and resets the meter.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .opacity(state == .paused && !hasArchived ? 1 : 0)
                .frame(maxWidth: .infinity, minHeight: hintSlotHeight, maxHeight: hintSlotHeight, alignment: .bottom)
                .padding(.bottom, 7)

            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    switch state {
                    case .idle:
                        meterButton("Start", systemImage: "play.fill", prominentTint: .blue) {
                            timerStore.start()
                        }
                    case .running:
                        meterButton("Pause", systemImage: "pause.fill") {
                            timerStore.pause()
                        }
                    case .paused:
                        meterButton("Resume", systemImage: "play.fill", prominentTint: .green) {
                            timerStore.start()
                        }
                        meterButton("Archive & Reset", systemImage: "archivebox.fill") {
                            archiveAndReset()
                        }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: state)
    }

    /// Glass button; pass `prominentTint` for the primary action of a state.
    @ViewBuilder
    private func meterButton(
        _ title: String,
        systemImage: String,
        prominentTint: Color? = nil,
        action: @escaping @MainActor () -> Void
    ) -> some View {
        let button = Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 30)
        }
        .controlSize(.large)

        if let prominentTint {
            button
                .buttonStyle(.glassProminent)
                .tint(prominentTint)
        } else {
            button
                .buttonStyle(.glass)
        }
    }

    private func archiveAndReset() {
        guard let session = timerStore.archiveAndReset(in: modelContext) else { return }
        hasArchived = true
        showToast("Saved to Records — \(amountText(session.totalEarned))")
    }

    // MARK: - Toast

    @ViewBuilder
    private var toast: some View {
        if let toastMessage {
            ToastView(message: toastMessage)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func showToast(_ message: String) {
        toastTask?.cancel()
        withAnimation(.spring(duration: 0.35)) {
            toastMessage = message
        }
        toastTask = Task {
            try? await Task.sleep(for: toastDuration)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                toastMessage = nil
            }
        }
    }

    // MARK: - Landscape

    private func landscapeLayout(width: CGFloat, now: Date) -> some View {
        Group {
            if width < 1000 {
                LandscapeMeter(
                    state: state,
                    amountText: amountText(timerStore.netEarned(at: now)),
                    elapsedText: elapsedClockText(timerStore.elapsed(at: now)),
                    showsElapsed: width > 700,
                    onPrimaryAction: {
                        // Archive & Reset lives only in portrait Paused.
                        if state == .running {
                            timerStore.pause()
                        } else {
                            timerStore.start()
                        }
                    }
                )
            } else {
                Text("Go get an iPhone")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Formatting

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
        Money.string(amount, symbol: currencySymbol)
    }

    private func perSecondText(_ value: Double) -> String {
        Money.string(value, symbol: currencySymbol, fractionDigits: 4...4)
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

// MARK: - Components

/// Ready / Running / Paused. Only the word "Running" pulses, and not under Reduce Motion.
private struct StateChip: View {
    let state: MeterState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var title: String {
        switch state {
        case .idle: "Ready"
        case .running: "Running"
        case .paused: "Paused"
        }
    }

    private var tint: Color {
        switch state {
        case .idle: .blue
        case .running: .green
        case .paused: .orange
        }
    }

    var body: some View {
        Group {
            if state == .running && !reduceMotion {
                Text(title)
                    .phaseAnimator([1.0, 0.55]) { content, opacity in
                        content.opacity(opacity)
                    } animation: { _ in
                        .easeInOut(duration: 0.9)
                    }
            } else {
                Text(title)
            }
        }
        .font(.system(size: 12.5, weight: .bold))
        .tracking(0.5)
        .textCase(.uppercase)
        .foregroundStyle(.primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        // Tinted Liquid Glass so the chip reads as its own layer over the matching background.
        .glassEffect(.regular.tint(tint.opacity(0.45)), in: .capsule)
        .animation(.easeInOut(duration: 0.2), value: state)
    }
}

/// Pure black landscape meter: amount and time centred, state label top-left, and a single
/// bottom-right button (Start / Pause / Resume) revealed by tapping anywhere.
private struct LandscapeMeter: View {
    let state: MeterState
    let amountText: String
    let elapsedText: String
    let showsElapsed: Bool
    let onPrimaryAction: () -> Void

    @State private var showsControls = true
    @State private var hideTask: Task<Void, Never>? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let controlsVisibleDuration: Duration = .milliseconds(3500)

    private var stateTitle: String {
        switch state {
        case .idle: "Ready"
        case .running: "Running"
        case .paused: "Paused"
        }
    }

    private var buttonTitle: String {
        switch state {
        case .idle: "Start"
        case .running: "Pause"
        case .paused: "Resume"
        }
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text(amountText)
                    .font(.system(size: 150, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.35)
                    .lineLimit(1)
                    .foregroundStyle(.white.opacity(0.82))

                if showsElapsed {
                    Text(elapsedText)
                        .font(.system(size: 36, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.82))
                }
            }
            .padding(.horizontal, 24)
        }
        .overlay(alignment: .topLeading) {
            stateLabel
                .padding(.leading, 26)
                .padding(.top, 22)
        }
        .overlay(alignment: .bottomTrailing) {
            primaryButton
                .padding(.trailing, 30)
                .padding(.bottom, 28)
                .opacity(showsControls ? 1 : 0)
                .allowsHitTesting(showsControls)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if showsControls {
                hideTask?.cancel()
                withAnimation(.easeInOut(duration: 0.3)) { showsControls = false }
            } else {
                revealControls()
            }
        }
        .onAppear(perform: revealControls)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var stateLabel: some View {
        let label = Text(stateTitle)
            .font(.system(size: 12.5, weight: .bold))
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundStyle(state == .running ? Color.green : Color.white.opacity(0.4))

        if state == .running && !reduceMotion {
            label.phaseAnimator([1.0, 0.55]) { content, opacity in
                content.opacity(opacity)
            } animation: { _ in
                .easeInOut(duration: 0.9)
            }
        } else {
            label
        }
    }

    private var primaryButton: some View {
        Button {
            onPrimaryAction()
            revealControls()
        } label: {
            Text(buttonTitle)
                .font(.system(size: 15, weight: .bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
        .buttonStyle(.glass)
        .controlSize(.large)
    }

    /// Shows the button and hides it again after a few seconds of no interaction.
    private func revealControls() {
        hideTask?.cancel()
        withAnimation(.easeInOut(duration: 0.3)) { showsControls = true }
        hideTask = Task {
            try? await Task.sleep(for: controlsVisibleDuration)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) { showsControls = false }
        }
    }
}

/// Session goal progress, shown only when a goal is set in Profile.
private struct GoalCard: View {
    let earned: Double
    let goal: Double
    let state: MeterState
    let format: (Double) -> String

    private var fraction: Double { min(1, max(0, earned / goal)) }
    private var isReached: Bool { earned >= goal }

    private var tint: Color {
        switch state {
        case .idle: .blue
        case .running: .green
        case .paused: .orange
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Session goal")
                    .font(.system(size: 11.5, weight: .bold))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Group {
                    if isReached {
                        Label("Reached \(format(goal))", systemImage: "checkmark.circle.fill")
                    } else {
                        Text("\(fraction.formatted(.percent.precision(.fractionLength(0)))) of \(format(goal))")
                    }
                }
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
            }

            ProgressView(value: fraction)
                .progressViewStyle(.linear)
                .tint(tint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentCard(cornerRadius: 16)
        .accessibilityElement(children: .combine)
    }
}

private struct StatTile: View {
    let label: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11.5, weight: .bold))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 1)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentCard(cornerRadius: 16)
        .accessibilityElement(children: .combine)
    }
}

extension View {
    /// Flat translucent card for content (glass is reserved for controls).
    func contentCard(cornerRadius: CGFloat) -> some View {
        background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.primary.opacity(0.09), lineWidth: 1)
            }
    }
}

#Preview {
    RootTabView()
        .environment(SalaryTimerStore(restoresSession: false))
        .modelContainer(for: SalarySession.self, inMemory: true)
}
