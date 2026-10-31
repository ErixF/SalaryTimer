//
//  SettingsView.swift
//  SalaryTimer
//
//  Created by Eric Feng on 6/5/26.
//

import SwiftUI
import UIKit

/// Settings, laid out like the system Settings app: a root list of icon rows that open detail
/// pages. On wide screens (Duo inner display, iPad) the list and the selected page sit side by
/// side; on phones the list pushes each page.
struct SettingsView: View {
    /// True when shown as a sheet (Alternative Look on wide screens): adds an X to close.
    var isSheet = false

    enum Pane: Hashable {
        case currency, income, deductions, sessionGoal
    }

    @AppStorage(ProfileKeys.incomeType) private var incomeType: Int = 0
    @AppStorage(ProfileKeys.hourlyRate) private var hourlyRateText: String = ""
    @AppStorage(ProfileKeys.monthlyIncome) private var monthlyIncomeText: String = ""
    @AppStorage(ProfileKeys.taxRate) private var taxRateText: String = ""
    @AppStorage(ProfileKeys.hoursPerDay) private var hoursPerDayText: String = ""
    @AppStorage(ProfileKeys.daysPerMonth) private var daysPerMonthText: String = ""
    @AppStorage(ProfileKeys.currencySymbol) private var currencySymbol: String = Money.defaultSymbol
    @AppStorage(ProfileKeys.sessionGoal) private var sessionGoalText: String = ""
    @AppStorage(ProfileKeys.alternativeLook) private var alternativeLook = false

    @Environment(SalaryTimerStore.self) private var timerStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dismiss) private var dismiss

    @State private var selection: Pane?
    @FocusState private var focusedField: Field?

    /// Input fields, used to scroll the focused one clear of the keyboard and its Done button.
    private enum Field: Hashable {
        case hourlyRate, monthlyIncome, hoursPerDay, daysPerMonth, deductions, sessionGoal
    }

    /// Room under the last footer so it scrolls clear of the floating tab bar.
    private let bottomScrollMargin: CGFloat = 72

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

    private var isLocked: Bool { timerStore.isRunning }

    /// Custom row fill on phones; on wide screens the sidebar keeps the system style so the
    /// selected row shows its highlight.
    private var rootRowBackground: RowBackground? {
        horizontalSizeClass == .regular ? nil : RowBackground()
    }

    var body: some View {
        NavigationSplitView {
            rootList
        } detail: {
            if let selection {
                pane(selection)
            } else {
                ScreenBackground().ignoresSafeArea()
            }
        }
        .onAppear {
            // Wide screens show a page next to the list, like Settings; start on the first one.
            if horizontalSizeClass == .regular, selection == nil {
                selection = .currency
            }
        }
    }

    // MARK: - Root list

    private var rootList: some View {
        List(selection: $selection) {
            statusSection

            Section {
                paneRow(.currency, title: "Currency", symbol: "dollarsign", color: .green, value: currencySymbol)
                paneRow(.income, title: "Income", symbol: "briefcase.fill", color: .blue, value: incomeSummary)
            }
            .listRowBackground(rootRowBackground)

            Section {
                paneRow(.deductions, title: "Deductions", symbol: "percent", color: .orange, value: deductionsSummary)
                paneRow(.sessionGoal, title: "Session Goal", symbol: "flag.checkered", color: .red, value: goalSummary)
            }
            .listRowBackground(rootRowBackground)

            Section {
                Toggle(isOn: $alternativeLook) {
                    Label {
                        Text("Alternative Look")
                    } icon: {
                        SettingsIcon(symbol: "rectangle.split.2x1", color: .gray)
                    }
                }
            } footer: {
                Text("Applies to iPhone Duo only.")
            }
            .listRowBackground(rootRowBackground)
        }
        .scrollContentBackground(.hidden)
        .background { ScreenBackground().ignoresSafeArea() }
        .navigationTitle("Settings")
        .toolbar {
            if isSheet {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
    }

    private func paneRow(_ pane: Pane, title: String, symbol: String, color: Color, value: String) -> some View {
        NavigationLink(value: pane) {
            LabeledContent {
                Text(value)
                    .monospacedDigit()
            } label: {
                Label {
                    Text(title)
                } icon: {
                    SettingsIcon(symbol: symbol, color: color)
                }
            }
        }
    }

    private var incomeSummary: String {
        if incomeType == 0 {
            return hourlyRateText.isEmpty ? "Not set" : "\(money(rates.hourlyRate))/hr"
        }
        return monthlyIncomeText.isEmpty ? "Not set" : "\(wholeMoney(rates.monthlyIncome))/mo"
    }

    private var deductionsSummary: String {
        rates.hasDeductions ? "\(number(rates.deduction))%" : "None"
    }

    private var goalSummary: String {
        SessionGoal.amount(from: sessionGoalText).map { wholeMoney($0) } ?? "Open"
    }

    // MARK: - Detail pages

    @ViewBuilder
    private func pane(_ pane: Pane) -> some View {
        switch pane {
        case .currency:
            paneForm("Currency") {
                Section {
                    Picker("Currency Symbol", selection: $currencySymbol) {
                        ForEach(Money.symbols, id: \.self) { symbol in
                            Text(symbol).tag(symbol)
                        }
                    }
                    .pickerStyle(.menu)
                } footer: {
                    Text("Symbol only — amounts aren't converted.")
                }
                .listRowBackground(RowBackground())
                .disabled(isLocked)
            }
        case .income:
            paneForm("Income") {
                Section {
                    // Each type keeps its own stored values; switching never clears the other.
                    Picker("Income Type", selection: $incomeType) {
                        Text("Hourly").tag(0)
                        Text("Monthly").tag(1)
                    }
                    .pickerStyle(.menu)

                    if incomeType == 0 {
                        valueRow("Hourly Rate", placeholder: "28", unit: "\(currencySymbol)/hr", text: $hourlyRateText, field: .hourlyRate)
                    } else {
                        valueRow("Monthly Income", placeholder: "4000", unit: "\(currencySymbol)/mo", text: $monthlyIncomeText, field: .monthlyIncome)
                        valueRow("Hours / Day", placeholder: "7", unit: "hrs", text: $hoursPerDayText, field: .hoursPerDay)
                        valueRow("Days / Month", placeholder: "22", unit: "days", text: $daysPerMonthText, field: .daysPerMonth)
                    }
                } footer: {
                    Text("Changes only affect upcoming sessions.")
                }
                .listRowBackground(RowBackground())
                .disabled(isLocked)

                rateSection
            }
        case .deductions:
            paneForm("Deductions") {
                Section {
                    valueRow("Deductions", placeholder: "Optional", unit: "%", text: $taxRateText, field: .deductions)
                } footer: {
                    Text("One combined % for tax and withholdings. Blank shows your gross rate. Changes only affect upcoming sessions.")
                }
                .listRowBackground(RowBackground())
                .disabled(isLocked)
            }
        case .sessionGoal:
            paneForm("Session Goal") {
                Section {
                    valueRow("Goal", placeholder: "Optional", unit: currencySymbol, text: $sessionGoalText, field: .sessionGoal)
                } footer: {
                    Text("Shown as a progress bar on the Meter and Lock Screen. Leave blank for open goal.")
                }
                .listRowBackground(RowBackground())
                .disabled(isLocked)
            }
        }
    }

    /// Shared page chrome: status line, navy background, keyboard handling.
    private func paneForm<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        let sections = content()
        return ScrollViewReader { proxy in
            Form {
                statusSection
                sections
            }
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, bottomScrollMargin, for: .scrollContent)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: focusedField) { _, field in
                guard let field else { return }
                // iOS only lifts the field to just above the keyboard, where the floating Done
                // button covers it; wait for the keyboard, then center the field instead.
                Task {
                    try? await Task.sleep(for: .milliseconds(350))
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(field, anchor: .center)
                    }
                }
            }
        }
        .background { ScreenBackground().ignoresSafeArea() }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                }
            }
        }
    }

    // MARK: - Status

    /// Running: inputs are locked. Paused: edits are allowed and apply from the next Resume.
    @ViewBuilder
    private var statusSection: some View {
        switch timerStore.state {
        case .running:
            statusRow("Locked while the meter is running. Pause or Archive & Reset to make changes.", systemImage: "lock.fill")
        case .paused:
            statusRow("Meter is paused. Changes apply when you resume.", systemImage: "pause.circle.fill")
        case .idle:
            EmptyView()
        }
    }

    private func statusRow(_ text: String, systemImage: String) -> some View {
        Section {
            Label(text, systemImage: systemImage)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .listRowBackground(RowBackground())
        }
    }

    // MARK: - Rate breakdown

    /// The rate math, one row per step, on a soft green accent.
    private var rateSection: some View {
        let rates = rates
        return Section {
            if rates.incomeType == 0 {
                rateRow("Hourly rate you entered", "\(money(rates.grossHourly))/hr")
            } else {
                rateRow("Monthly income you entered", wholeMoney(rates.monthlyIncome))
                rateRow(
                    "Hours in a month",
                    "\(number(rates.daysPerMonth)) × \(number(rates.hoursPerDay)) = \(number(rates.monthlyHours)) hrs"
                )
                rateRow("Gross hourly rate", "\(money(rates.grossHourly))/hr")
            }

            if rates.hasDeductions {
                rateRow(
                    "Less deductions (\(number(rates.deduction))%)",
                    "−\(money(rates.grossHourly - rates.netHourly))/hr"
                )
            }

            rateRow(
                rates.hasDeductions ? "Take-home rate" : "Gross rate",
                "\(money(rates.netHourly))/hr",
                isResult: true
            )
            rateRow("Per second", "\(Money.string(rates.netPerSecond, symbol: currencySymbol, fractionDigits: 4...4))/sec")

            if rates.incomeType == 0 {
                rateRow("Per 8-hour day", money(rates.netHourly * 8))
            }
        } header: {
            Text("Your Rate Calculated")
        }
        .listRowBackground(Color.green.opacity(colorScheme == .dark ? 0.16 : 0.12))
    }

    private func rateRow(_ label: String, _ value: String, isResult: Bool = false) -> some View {
        LabeledContent {
            Text(value)
                .monospacedDigit()
                .foregroundStyle(isResult ? .green : .secondary)
                .fontWeight(isResult ? .bold : .regular)
        } label: {
            Text(label)
                .fontWeight(isResult ? .bold : .regular)
        }
    }

    // MARK: - Rows

    /// Settings-style editable row: label on the left, right-aligned value and gray unit on the right.
    private func valueRow(_ title: String, placeholder: String, unit: String, text: Binding<String>, field: Field) -> some View {
        LabeledContent(title) {
            HStack(spacing: 6) {
                TextField(placeholder, text: text)
                    .focused($focusedField, equals: field)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                Text(unit)
                    .foregroundStyle(.secondary)
            }
        }
        .id(field)
    }

    // MARK: - Formatting

    private func money(_ value: Double) -> String {
        Money.string(value, symbol: currencySymbol)
    }

    /// `$4,000` — no forced decimals for whole amounts.
    private func wholeMoney(_ value: Double) -> String {
        Money.string(value, symbol: currencySymbol, fractionDigits: 0...2)
    }

    private func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
}

/// White SF Symbol on a colored rounded square, like the icons in the Settings app.
private struct SettingsIcon: View {
    let symbol: String
    let color: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 29, height: 29)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

#Preview {
    SettingsView()
        .environment(SalaryTimerStore(restoresSession: false))
}
