//
//  SettingsView.swift
//  SalaryTimer
//
//  Created by Eric Feng on 6/5/26.
//

import SwiftUI
import UIKit

/// Settings tab, laid out like the system Settings app: a native grouped Form with
/// label-left / value-right rows and short footers.
struct SettingsView: View {
    @AppStorage(ProfileKeys.incomeType) private var incomeType: Int = 0
    @AppStorage(ProfileKeys.hourlyRate) private var hourlyRateText: String = ""
    @AppStorage(ProfileKeys.monthlyIncome) private var monthlyIncomeText: String = ""
    @AppStorage(ProfileKeys.taxRate) private var taxRateText: String = ""
    @AppStorage(ProfileKeys.hoursPerDay) private var hoursPerDayText: String = ""
    @AppStorage(ProfileKeys.daysPerMonth) private var daysPerMonthText: String = ""
    @AppStorage(ProfileKeys.currencySymbol) private var currencySymbol: String = Money.defaultSymbol
    @AppStorage(ProfileKeys.sessionGoal) private var sessionGoalText: String = ""

    @Environment(SalaryTimerStore.self) private var timerStore
    @Environment(\.colorScheme) private var colorScheme

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

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            Form {
                statusSection

                Section {
                    Picker("Currency Symbol", selection: $currencySymbol) {
                        ForEach(Money.symbols, id: \.self) { symbol in
                            Text(symbol).tag(symbol)
                        }
                    }
                    .pickerStyle(.menu)
                    .listRowBackground(RowBackground())
                } header: {
                    Text("Currency")
                } footer: {
                    Text("Symbol only — amounts aren't converted.")
                }
                .disabled(isLocked)

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
                } header: {
                    Text("Income")
                } footer: {
                    Text("Changes only affect upcoming sessions.")
                }
                .listRowBackground(RowBackground())
                .disabled(isLocked)

                rateSection

                Section {
                    valueRow("Deductions", placeholder: "Optional", unit: "%", text: $taxRateText, field: .deductions)
                } header: {
                    Text("Deductions")
                } footer: {
                    Text("One combined % for tax and withholdings. Blank shows your gross rate. Changes only affect upcoming sessions.")
                }
                .listRowBackground(RowBackground())
                .disabled(isLocked)

                Section {
                    valueRow("Goal", placeholder: "Optional", unit: currencySymbol, text: $sessionGoalText, field: .sessionGoal)
                } header: {
                    Text("Session Goal")
                } footer: {
                    Text("Shown as a progress bar on the Meter and Lock Screen. Leave blank for open goal.")
                }
                .listRowBackground(RowBackground())
                .disabled(isLocked)
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
            .background {
                ScreenBackground()
                    .ignoresSafeArea()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
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

#Preview {
    SettingsView()
        .environment(SalaryTimerStore(restoresSession: false))
}
